#!/bin/bash

# Install WireGuard
sudo apt-get install -y wireguard

# Generate WireGuard keys
wg genkey | tee privatekey | wg pubkey > publickey

# Cat public key and display email
printf "\n\nSend an email to hiac@gmail.com with the your public key: $(cat publickey)\n\n"