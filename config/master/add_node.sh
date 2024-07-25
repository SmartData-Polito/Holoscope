#!/bin/bash

# Default values
DEFAULT_WG_PK="K30I8eIxuBL3OA43Xl34x0Tc60wqyDBx4msVm8VLkAE="
DEFAULT_WG_IP="10.0.0.2"

# Function to display help message
show_help() {
    echo "Usage: $0 [WG_PK] [WG_IP]"
    echo "  WG_PK   The WireGuard peer Public Key (default: $DEFAULT_WG_PK)"
    echo "  WG_IP   The WireGuard peer IP address (default: $DEFAULT_WG_IP)"
    echo "  --help  Display this help message and exit"
}

# Check if the --help option is provided
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Command line arguments with defaults
WG_PK="${1:-$DEFAULT_WG_PK}"
WG_IP="${2:-$DEFAULT_WG_IP}"

# Add peer into network
sudo wg set wg0 peer $WG_PK allowed-ips $WG_IP/32
sudo ip -4 route add $WG_IP/32 dev wg0

# Save configuration
sudo wg-quick save wg0