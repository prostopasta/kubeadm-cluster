#!/bin/bash
set -ex

# Install containerd
#apt-get install -y containerd
# containerd -v
# containerd github.com/containerd/containerd 1.7.27


# Will install containerd from Docker's repository instead of the default Ubuntu repository.

# Run the following command to uninstall all conflicting packages:
for pkg in \
  docker.io docker-doc docker-compose \
  docker-compose-v2 podman-docker containerd runc; \
  do apt-get remove $pkg; done | true

# Add Docker's official GPG key:
apt-get update
apt-get install ca-certificates curl -y
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install containerd.io -y

containerd config default | tee /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i 's/pause:3.8/pause:3.10/' /etc/containerd/config.toml

grep -Ei '(pause:|systemdc)' /etc/containerd/config.toml
    # sandbox_image = "registry.k8s.io/pause:3.10"
    #         SystemdCgroup = true

sudo systemctl restart containerd

# Check versions

containerd -v
# containerd containerd.io 1.7.27

runc -v
# runc version 1.2.5
# commit: v1.2.5-0-g59923ef
# spec: 1.2.0
# go: go1.23.7
# libseccomp: 2.5.3
