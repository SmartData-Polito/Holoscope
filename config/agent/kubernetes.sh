#!/bin/bash

# Default values
DEFAULT_WG_IP="10.0.0.101"
DEFAULT_K3S_URL="https://10.0.0.100:6443"
DEFAULT_K3S_TOKEN="K10435bfc49da4123378b10ba69c1dc0b3f137d6485caea2e4187a1b24be9fc4146::server:7bd822441a280463533c4cea5e5cb393"
DEFAULT_K3S_NODE_NAME="agent1"

# Function to display help message
show_help() {
    echo "Usage: $0 [WG_IP] [K3S_URL] [K3S_TOKEN] [K3S_NODE_NAME]"
    echo "  WG_IP           The WireGuard IP address (default: $DEFAULT_WG_IP)"
    echo "  K3S_URL         The K3S server URL (default: $DEFAULT_K3S_URL)"
    echo "  K3S_TOKEN       The K3S server token (default: $DEFAULT_K3S_TOKEN)"
    echo "  K3S_NODE_NAME   The K3S node name (default: $DEFAULT_K3S_NODE_NAME)"
    echo "  --help          Display this help message and exit"
}

# Check if the --help option is provided
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Command line arguments with defaults
WG_IP="${1:-$DEFAULT_WG_IP}"
K3S_URL="${2:-$DEFAULT_K3S_URL}"
K3S_TOKEN="${3:-$DEFAULT_K3S_TOKEN}"
K3S_NODE_NAME="${4:-$DEFAULT_K3S_NODE_NAME}"

# Install K3s with WireGuard
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN K3S_NODE_NAME=$K3S_NODE_NAME sh -s - agent 
 
# Check for an empty line and remove it before appending the echo message
sed -i '/^$/d' /etc/systemd/system/k3s-agent.service

# Configure flannel in node
echo "ExecStart=/usr/local/bin/k3s agent --node-ip $WG_IP --flannel-iface=wg0" | sudo tee -a /etc/systemd/system/k3s-agent.service

# Restart k3s service
sudo systemctl daemon-reload
sudo systemctl restart k3s-agent.service

# Unset variables
unset WG_IP K3S_URL K3S_TOKEN K3S_NODE_NAME
