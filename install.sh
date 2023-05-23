#!/bin/bash

rm -rf awx-operator
minikube delete

minikube start
git clone https://github.com/ansible/awx-operator.git
kubectl create ns awx
cd awx-operator/
RELEASE_TAG=`curl -s https://api.github.com/repos/ansible/awx-operator/releases/latest | grep tag_name | cut -d '"' -f 4`
echo $RELEASE_TAG
git checkout $RELEASE_TAG
kubectl config set-context --current --namespace=awx
export NAMESPACE=awx
make deploy
echo 'Wait for awx operator deployment...'
sleep 120
kubectl create -f ../pvc.yml
kubectl get pvc
kubectl create -f ../awx-demo.yml
echo 'Wait for awx deployment...'
sleep 120
minikube service -n awx awx-service --url
kubectl get secret awx-admin-password -o jsonpath="{.data.password}" | base64 --decode ; echo
sleep 120
echo 'Done'