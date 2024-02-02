#!/bin/bash

# Set the WireGuard IP address
WG_IP="10.0.0.5"

# Install K3s with WireGuard
curl -sfL https://get.k3s.io | K3S_URL=https://10.0.0.1:6443 K3S_TOKEN=K1047421038c1a6b28861b8d4ac1e001f0ce65c8201606732dc444c47c837c3864f::server:ca4392a1e9d257daeaf4ab0d57237226 K3S_NODE_NAME=name-node sh - 

# Check for an empty line and remove it before appending the echo message
sed -i '/^$/d' /etc/systemd/system/k3s-agent.service

# Configure flannel in node
echo "ExecStart=/usr/local/bin/k3s agent --node-ip $WG_IP --flannel-iface=wg0" | sudo tee -a /etc/systemd/system/k3s-agent.service

# Restart k3s service
sudo systemctl daemon-reload 
sudo systemctl restart k3s-agent.service

# Unset the WireGuard IP address variable
unset WG_IP