#!/bin/bash

# Default values
DEFAULT_WG_IP="10.0.0.3"
DEFAULT_PUBLIC_KEY="VVx1dnVeVgT4vw7qVYONY5e+8oyt8aK0CHpdKIto0Q4="
DEFAULT_ALLOWED_IPS="10.0.0.1/32"
DEFAULT_ENDPOINT="kubernetes.polito.it:51820"

# Function to display help message
show_help() {
    echo "Usage: $0 [WG_IP] [PublicKey] [AllowedIPs] [Endpoint]"
    echo "  WG_IP       The WireGuard IP address (default: $DEFAULT_WG_IP)"
    echo "  PublicKey   The WireGuard peer Public Key (default: $DEFAULT_PUBLIC_KEY)"
    echo "  AllowedIPs  The IPs allowed for the WireGuard peer (default: $DEFAULT_ALLOWED_IPS)"
    echo "  Endpoint    The WireGuard peer endpoint (default: $DEFAULT_ENDPOINT)"
    echo "  --help      Display this help message and exit"
}

# Check if the --help option is provided
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Command line arguments with defaults
WG_IP="${1:-$DEFAULT_WG_IP}"
PublicKey="${2:-$DEFAULT_PUBLIC_KEY}"
AllowedIPs="${3:-$DEFAULT_ALLOWED_IPS}"
Endpoint="${4:-$DEFAULT_ENDPOINT}"

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
PublicKey = $PublicKey
Endpoint = $Endpoint
AllowedIPs = $AllowedIPs
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

# Unset variables
unset WG_IP PublicKey AllowedIPs Endpoint