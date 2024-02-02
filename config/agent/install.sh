#!/bin/bash

# Set the WireGuard IP address
WG_IP="10.0.0.5"

# Install WireGuard
sudo apt-get install -y wireguard

# Generate WireGuard keys
wg genkey | tee privatekey | wg pubkey > publickey

# Create WireGuard configuration file
sudo bash -c "cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = $WG_IP/24
PrivateKey = $(cat privatekey)

[Peer]
PublicKey = VVx1dnVeVgT4vw7qVYONY5e+8oyt8aK0CHpdKIto0Q4=
Endpoint = kubernetes.polito.it:51820
AllowedIPs = 10.0.0.1/32
EOF"

# Create WireGuard Up service file
sudo bash -c "cat > /etc/systemd/system/wireguard-up.service << EOF
[Unit]
Description=WireGuard Up Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/wg-quick up wg0

[Install]
WantedBy=default.target
EOF"

# Reload systemd and start WireGuard service
sudo systemctl daemon-reload
sudo systemctl enable wireguard-up.service
sudo systemctl start wireguard-up.service

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
