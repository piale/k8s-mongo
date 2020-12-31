#!/bin/bash

kubectl apply -f mongodb-secret.yaml
kubectl apply -f mongodb-deployment.yaml
kubectl apply -f mongo-configmap.yaml
kubectl apply -f mongo-express-secret.yaml
kubectl apply -f mongo-express-deployment.yaml

