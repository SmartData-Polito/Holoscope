# K3s Cluster with WireGuard for Honeypots Deployment

## Overview

This project aims to set up a K3s cluster using WireGuard for secure communication and deploy honeypots for monitoring and analyzing potential security threats. The cluster consists of a master node and multiple agent nodes connected through WireGuard VPN.

## Prerequisites

### Single Node Setup:

- Operating System: Linux distribution (e.g., Ubuntu 20.04)
- Resources: Adequate CPU and memory
- Dependencies: Docker installed on the node

### Multiple Nodes Setup (Master - Agents):

- Operating System: Linux distribution (e.g., Ubuntu 20.04) for both master and agent nodes
- Resources: Master - sufficient CPU, memory, and storage; Agents - similar requirements as master
- Dependencies: Docker installed on all nodes

## Installation

### Master Node:

1. Navigate to the `config/master/install.sh` file.
2. Modify WP_IP with the desired ip address for your VPN.
3. Change iface with the internet interface.
4. Execute the installation script for the master node.
5. Provide K3S_TOKEN located in /var/lib/rancher/k3s/server/node-token to each agent.
6. Share master wireguard public key to each agent and their respective wireguard ip.
5. Add each agent to the VPN using: `wg set wg0 peer <agent_pubkey> allowed-ips <agent_vpn_ip>/32` following by `sudo ip -4 route add $WG_IP/32 dev wg0` or run `config/master/add_node.sh` file.


### Agent Nodes:

#### Wireguard

1. Navigate to the `config/node/wireguard.sh` file.
2. Change the WG_IP variable by the IP assaigned by the master node.
3. Execute the wireguard installation script for the agent node.
4. Send the wireguard public key to the master to be join.
5. Wait until the master add you to the VPN.

#### K3S
1. Navigate to the `config/node/kubernetes.sh` file.
2. Configure the K3S_TOKEN by the Token assaigned by the master node.
3. Set K3S_NODE_NAME according to the desidered name.
4. Execute the k3s installation script for the agent node.
5. Send the wireguard public key to the master to be join.


## Honeypots Deployment
1. Join Nodes to the Cluster:
   - Ensure all nodes (master and agents) are successfully joined to the K3s cluster.

2. Honeypot Deployment:
   - Explore the `manifest` folder for example YAML files used in tests.
   - Customize or add different honeypots to deploy.

3. Deploy Honeypots:
   ```bash
   kubectl apply -f manifest
