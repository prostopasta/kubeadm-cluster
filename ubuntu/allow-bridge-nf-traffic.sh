#!/bin/bash
# This script allows bridge-nf traffic for Kubernetes networking
# It is typically run on all control plane and worker nodes in a Kubernetes cluster.

set -xe

# Ensure the br_netfilter module is loaded
if ! lsmod | grep -q br_netfilter; then
    echo "br_netfilter module is not loaded. Loading it now..."
    modprobe br_netfilter
else
    echo "br_netfilter module is already loaded."
fi

# Ensure the br_netfilter module is loaded on boot
if ! grep -q "br_netfilter" /etc/modules-load.d/k8s.conf; then
    echo "Adding br_netfilter module to /etc/modules-load.d/k8s.conf..."
    echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
else
    echo "br_netfilter module is already configured to load on boot."
fi

# Ensure the necessary sysctl configuration file exists
if [ ! -f /etc/sysctl.d/k8s.conf ]; then
    echo "Creating sysctl configuration file for Kubernetes..."
    touch /etc/sysctl.d/k8s.conf
else
    echo "Sysctl configuration file for Kubernetes already exists."
fi

# Ensure the sysctl settings for bridge-nf traffic are present
if grep -Eq "^net.bridge.bridge-nf-call-iptables.?=.?1" /etc/sysctl.d/k8s.conf; then
    echo "Sysctl settings for bridge-nf traffic are already applied."
else
    # Ensure the necessary sysctl settings are applied
    echo "Applying sysctl settings for bridge-nf traffic..."
    echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.d/k8s.conf
    echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/k8s.conf

    # Reload sysctl settings
    echo "Reloading sysctl settings..."
    sysctl --system
fi

# Enable IP forwarding
if grep -Eq "^net.ipv4.ip_forward.?=.?1" /etc/sysctl.conf; then
    echo "IP forwarding is already enabled."
else
    echo "Enabling IP forwarding..."
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi

# Reload sysctl settings to apply changes
sysctl -p
