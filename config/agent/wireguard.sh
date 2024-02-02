#!/bin/bash

# Set the WireGuard IP address
WG_IP="10.0.0.3"

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

unset WG_IP