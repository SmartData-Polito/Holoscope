# CyBorg – Distributed Edge Platform for Cybersecurity Data Collection and Machine Learning

## Overview

**CyBorg** is a distributed edge platform designed for cybersecurity data collection and machine learning applications. The platform operates with multiple capabilities:

1. **Passive Measurement Probes**: CyBorg enables the deployment of passive network probes for performance measurements, including darknet monitoring, to track ongoing network scanning activities.

2. **Active Cybersecurity Probes**: CyBorg supports the deployment of a honeynet - a distributed network of honeypots at the edge that monitors ongoing network attacks. It includes the deployment of some classic low-interaction honeypot such as Cowrie.

3. **Testbed for Vulnerabilities**: CyBorg helps the deployment of vulnerable applications that can be exploited by internal nodes or serve as high-interaction honeypots.

4. **Data Collection Platform**: CyBorg manages the deployment of crawlers for distributed data collection across various sources.

5. **Federated Learning**: CyBorg implements distributed training of ML tasks using data collected by the above probes. This federated learning approach allows the development of ML models on distributed data without requiring direct data exchange between nodes.

This platform is lightweight, stable, and scalable, built on [K3s](https://k3s.io/) for Kubernetes management and [Ansible](https://www.ansible.com/) for automated deployment and configuration.

**If you are interested in joining the network contact the maintainers**

---

## Why the Name **CyBorg**?

The name **CyBorg** is inspired by the **Borg**, a collective race from the _Star Trek_ universe. The Borg are known for their interconnected, hive-mind system where each individual unit contributes to the greater whole. Similarly, **CyBorg** reflects the idea of multiple distributed nodes working together to form a powerful, collective platform for cybersecurity.

---

## Project Structure

```
├── applications/             # Containerized applications
│   ├── cowrie/               # SSH/Telnet honeypot
│   ├── darknet/              # Darknet monitoring probes
│   ├── idarkvec/             # Federated learning IP reputation application
│   └── l4responder/          # Layer 4 response simulator
├── infrastructure/           # Platform infrastructure
│   ├── ansible/              # Ansible automation
│   │   ├── inventory/        # Environment configurations
│   │   ├── playbooks/        # Deployment playbooks
│   │   └── roles/            # Ansible roles
│   ├── helm/                 # Helm charts for Kubernetes
│   └── vagrant/              # Local development environment
└── README.md
```

## Architecture

- **K3s**: A lightweight Kubernetes distribution for running services on edge nodes
- **Ansible**: Automation tool for managing deployment and configuration
- **Docker**: Containerization of applications
- **Helm**: Kubernetes package manager for application deployment
- **Vagrant**: Local development environment setup

## Available Applications

### Security Monitoring
- **Darknet**: Passive network monitoring and scanning detection
- **L4Responder**: Layer 4 protocol response simulation
- **honeypots**: External honeypots included as modules (see Cowrie)

### Machine Learning
- **IDarkVec**: Federated learning platform with flower server/client architecture

## Prerequisites

### Development Environment (Single Node)
- **Operating System**: Linux (e.g., Ubuntu 24.04)
- **Resources**: Adequate CPU and memory for running at least 3 VMs for testing
- **Dependencies**: 
  - Vagrant
  - VirtualBox or Libvirt
  - Ansible
  - Docker

### Production Environment (Multiple Nodes)
- **Operating System**: Linux on all nodes
- **Resources**: 
  - **Master**: At least 2 CPUs, 16 GB of memory, and sufficient storage (~20 GBs for retention of honeypot logs)
  - **Agents**: Similar to master requirements
- **Network**: Secure connectivity between nodes (WireGuard VPN supported)

## Quick Start

### 1. Development Environment Setup

For local development using Vagrant:

```bash
cd infrastructure/vagrant
./install.sh  # Automated setup on Linux
# or manually:
vagrant up
```

See [Vagrant README](infrastructure/vagrant/README.md) for detailed setup instructions.

### 2. Production Deployment

#### Step 1: Configure Inventory
Edit the inventory files to match your environment:
```bash
# Development environment
infrastructure/ansible/inventory/environments/dev/hosts.yml

# Production environment  
infrastructure/ansible/inventory/environments/prod/hosts.yml
```

#### Step 2: Initialize Infrastructure
Deploy K3s cluster and basic infrastructure:
```bash
cd infrastructure/ansible
ansible-playbook -i inventory/environments/dev/hosts.yml -i inventory/ playbooks/site.yml --ask-vault-password
```

#### Step 3: Deploy Container Registry
Set up local container registry for storing application images:
```bash
ansible-playbook -i inventory/environments/dev/hosts.yml -i inventory/ playbooks/registry.yml
```

#### Step 4: Build Application Images
Build and push all application Docker images to the registry:
```bash
ansible-playbook -i inventory/environments/dev/hosts.yml -i inventory/ playbooks/build.yml
```

#### Step 5: Deploy Applications
Deploy selected applications based on your `hosts.yml` configuration:
```bash
ansible-playbook -i inventory/environments/dev/hosts.yml -i inventory/ playbooks/deploy.yml
```

## Configuration

### Environment Selection
The platform supports multiple environments:
- **Development**: `inventory/environments/dev/`
- **Production**: `inventory/environments/prod/`

### Application Selection
Configure which applications to deploy by editing the group variables in your inventory:
```yaml
# Example: infrastructure/ansible/inventory/environments/dev/group_vars/all.yml
deploy_applications:
  - cowrie
  - darknet
  - idarkvec
```

### Network Configuration
The platform requires various network configurations:
- **WireGuard VPN**: For secure inter-node communication
- **Darknet Monitoring**: For passive/active network experiments
- **Network Policies**: Kubernetes network policies for application isolation

### Add New Nodes
```bash
ansible-playbook -i inventory/environments/dev/hosts.yml -i inventory/ playbooks/add_node.yml
```

### Reset Cluster
```bash
ansible-playbook -i inventory/environments/dev/hosts.yml -i inventory/ playbooks/reset.yml
```

## Maintainers

- Idilio Drago
- Andrea Sordello  
- Rodolfo Vieira Valentim

