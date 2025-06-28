#!/bin/bash
# This script updates the DNS configuration on an Ubuntu system to use Google's public DNS (

set -xe

sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf

# Restart the DNS service to apply changes
systemctl restart systemd-resolved

# Ensure the DNS service is running
if systemctl is-active --quiet systemd-resolved; then
    echo "systemd-resolved is running."
else
    echo "systemd-resolved is not running. Starting it now..."
    systemctl start systemd-resolved
    if systemctl is-active --quiet systemd-resolved; then
        echo "systemd-resolved started successfully."
    else
        echo "Failed to start systemd-resolved."
        exit 1
    fi
fi

# Check if the DNS service is enabled to start on boot
if systemctl is-enabled --quiet systemd-resolved; then
    echo "systemd-resolved is enabled to start on boot."
else
    echo "systemd-resolved is not enabled to start on boot. Enabling it now..."
    systemctl enable systemd-resolved
    if systemctl is-enabled --quiet systemd-resolved; then
        echo "systemd-resolved enabled successfully."
    else
        echo "Failed to enable systemd-resolved."
        exit 1
    fi
fi

# Check the status of the DNS service
if systemctl status systemd-resolved | grep -q "active (running)"; then
    echo "systemd-resolved is active and running."
else
    echo "systemd-resolved is not active. Please check the logs for more details."
    systemctl status systemd-resolved
    exit 1
fi

# Check if the DNS service is configured to use Google's public DNS
if grep -q "DNS=8.8.8.8" /etc/systemd/resolved.conf; then
    echo "DNS is configured correctly in /etc/systemd/resolved.conf."
else
    echo "DNS is not configured correctly in /etc/systemd/resolved.conf. Please check the configuration."
    exit 1
fi

# Check if the DNS service is resolving names correctly
if resolvectl status | grep "DNS Servers: 8.8.8.8"; then
    echo "DNS is resolving names correctly."
else
    echo "DNS is not resolving names correctly. Please check the DNS configuration."
    exit 1
fi

# Check if the DNS service is reachable
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "DNS service is reachable."
else
    echo "DNS service is not reachable. Please check your network configuration."
    exit 1
fi

# Show the current DNS configuration
echo "Current DNS configuration:"
resolvectl status
