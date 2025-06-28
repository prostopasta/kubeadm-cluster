#!/bin/bash
set -ex

apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key -o Release.key
gpg --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --dearmor Release.key

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
systemctl enable kubelet
systemctl start kubelet

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Check versions
kubelet --version
kubeadm version
kubectl version --client
