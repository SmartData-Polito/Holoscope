#!/bin/bash

# Set Wireguard peer Public Key
WG_Pk="K30I8eIxuBL3OA43Xl34x0Tc60wqyDBx4msVm8VLkAE="

# Set Wireguard peer IP address
WG_IP="10.0.0.2"

# Add peer into network
sudo wg set wg0 peer $WG_PK allowed-ips $WG_IP/32
sudo ip -4 route add $WG_IP/32 dev wg0

# Save configuration
sudo wg-quick save wg0
