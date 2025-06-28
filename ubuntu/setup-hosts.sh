#!/bin/bash
# This script sets up the /etc/hosts file for a Kubernetes cluster on Ubuntu.
# It updates the hosts file with the IP addresses and hostnames of the control plane and worker nodes.
# It is typically run on all control plane and worker nodes in a Kubernetes cluster.
# Usage: ./setup-hosts.sh <interface_name> <hostname>

set -ex

IFNAME=$1
ADDRESS="$(ip -4 addr show "${IFNAME}" | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
NETWORK=$(echo "${ADDRESS}" | awk 'BEGIN {FS="."} ; { printf("%s.%s.%s", $1, $2, $3) }')

#sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

# remove ubuntu-jammy entry
sed -e '/^.*ubuntu-jammy.*/d' -i /etc/hosts

# Update /etc/hosts about other hosts
cat >> /etc/hosts <<EOF
${NETWORK}.11  controlplane01
${NETWORK}.12  controlplane02
${NETWORK}.13  controlplane03
${NETWORK}.21  node01
${NETWORK}.22  node02
${NETWORK}.23  node03
${NETWORK}.30  lb
EOF
