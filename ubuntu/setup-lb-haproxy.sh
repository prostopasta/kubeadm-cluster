#!/bin/bash
# This script sets up HAProxy as a load balancer for the Kubernetes control plane nodes.

set -xe

IFNAME=$1
ADDRESS="$(ip -4 addr show "${IFNAME}" | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
NETWORK=$(echo "${ADDRESS}" | awk 'BEGIN {FS="."} ; { printf("%s.%s.%s", $1, $2, $3) }')

apt-get update -y
apt-get install -y haproxy net-tools

cat > /etc/haproxy/haproxy.cfg <<EOF
# This is the main configuration file for HAProxy
# It is used to configure the load balancer for the Kubernetes control plane nodes.

frontend kubernetes-frontend
    bind ${NETWORK}.30:6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server controlplane01 ${NETWORK}.11:6443 check fall 3 rise 2
    server controlplane02 ${NETWORK}.12:6443 check fall 3 rise 2
    server controlplane03 ${NETWORK}.13:6443 check fall 3 rise 2
EOF

# Enable HAProxy to start on boot
systemctl enable haproxy
# Restart HAProxy to apply the new configuration
systemctl restart haproxy
# Check the status of HAProxy to ensure it's running correctly
systemctl status haproxy

# Check if HAProxy is listening on the expected port
if netstat -tuln | grep -q "${NETWORK}.30:6443"; then
    echo "HAProxy is listening on ${NETWORK}.30:6443"
else
    echo "HAProxy is not listening on ${NETWORK}.30:6443. Please check the configuration."
    exit 1
fi

# Check HAProxy configuration for syntax errors
if ! haproxy -c -f /etc/haproxy/haproxy.cfg; then
    echo "HAProxy configuration has syntax errors. Please fix them before proceeding."
    exit 1
else
    echo "HAProxy configuration is valid."
fi
