#!/bin/bash

K8S_IP_ADDRESS=172.17.47.252
PODS_NETWORK=10.245.0.0/16
K8S_VERSION=1.19.6-00
K8S_VERSION_SHORT=1.19.6

sudo sed -i 's|/swap.img|#/swap.img|' /etc/fstab
sudo swapoff -a

sudo apt-get update -y
sudo apt-get upgrade -y

sudo apt-get update && sudo apt-get install -y \
  apt-transport-https ca-certificates curl software-properties-common gnupg2

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key --keyring /etc/apt/trusted.gpg.d/docker.gpg add -

sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"
  
sudo apt-get update -y && sudo apt-get install -y \
  containerd.io=1.2.13-2 \
  docker-ce=5:19.03.11~3-0~ubuntu-$(lsb_release -cs) \
  docker-ce-cli=5:19.03.11~3-0~ubuntu-$(lsb_release -cs)
  
sudo mkdir /etc/docker

cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
}
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker

sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo apt-get update -y
sudo apt-get install -y kubeadm=$K8S_VERSION kubelet=$K8S_VERSION kubectl=$K8S_VERSION
sudo apt-mark hold kubelet kubeadm kubectl

sudo kubeadm init --pod-network-cidr=$PODS_NETWORK --upload-certs | sudo tee kubeadm-init.out

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo 'source <(kubectl completion bash)' >> $HOME/.bashrc

source $HOME/.bashrc

kubectl taint nodes --all node-role.kubernetes.io/master-

wget https://docs.projectcalico.org/manifests/calico.yaml

sudo sed -zi 's|            # - name: CALICO_IPV4POOL_CIDR\n            #   value: "192.168.0.0/16"|            - name: CALICO_IPV4POOL_CIDR\n              value: '"$PODS_NETWORK"'|' calico.yaml
kubectl apply -f calico.yaml

sudo apt-get install git -y

git clone https://github.com/nginxinc/kubernetes-ingress/
cd kubernetes-ingress/deployments
git checkout v1.9.1
kubectl apply -f common/ns-and-sa.yaml
kubectl apply -f rbac/rbac.yaml

kubectl apply -f common/default-server-secret.yaml
kubectl apply -f common/nginx-config.yaml
kubectl apply -f common/ingress-class.yaml
kubectl apply -f daemon-set/nginx-ingress.yaml
