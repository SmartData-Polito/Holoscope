#!/bin/bash

# Install WireGuard
sudo apt-get install -y wireguard

# Generate WireGuard keys
wg genkey | tee privatekey | wg pubkey > publickey

# Cat public key and display email
echo send an email to hiabpolito@gmail.com with the your public key: $(cat publickey)

# Create WireGuard configuration file
sudo bash -c "cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.0.0.5/24
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
curl -sfL https://get.k3s.io | K3S_URL=https://10.0.0.1:6443 K3S_TOKEN=K1047421038c1a6b28861b8d4ac1e001f0ce65c8201606732dc444c47c837c3864f::server:ca4392a1e9d257daeaf4ab0d57237226 sh - 