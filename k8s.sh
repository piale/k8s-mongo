#!/bin/bash

PODS_SUBNET=10.10.0.0/16
K8S_VERSION=1.19.6-00
K8S_VERSION_SHORT=1.19.6
CONTROL_PLANE_ENDPOINT=master:6443

sudo sed -i 's|/swap.img|#/swap.img|' /etc/fstab
sudo swapoff -a

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install docker.io -y

sudo systemctl enable docker.service
sudo systemctl start docker.service

sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo apt-get update -y
sudo apt-get install -y kubeadm=$K8S_VERSION kubelet=$K8S_VERSION kubectl=$K8S_VERSION
sudo apt-mark hold kubelet kubeadm kubectl

cat <<EOF | sudo tee kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: $K8S_VERSION_SHORT
controlPlaneEndpoint: "$CONTROL_PLANE_ENDPOINT"
networking:
  podSubnet: $PODS_SUBNET
EOF

sudo kubeadm init --config=kubeadm-config.yaml --upload-certs | sudo tee kubeadm-init.out

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo 'source <(kubectl completion bash)' >> $HOME/.bashrc

kubectl taint nodes --all node-role.kubernetes.io/master-

wget https://docs.projectcalico.org/manifests/calico.yaml

sudo sed -zi 's|            # - name: CALICO_IPV4POOL_CIDR\n            #   value: "192.168.0.0/16"|            - name: CALICO_IPV4POOL_CIDR\n              value: '"$PODS_SUBNET"'|' calico.yaml
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
