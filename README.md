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
## Architecture

- **K3s**: A lightweight Kubernetes distribution for running services on edge nodes.
- **Ansible**: Automation tool for managing deployment and configuration.

## Prerequisites

### Single Node Setup (for development):
- **Operating System**: Linux (e.g., Ubuntu 20.04)
- **Resources**: Adequate CPU and memory for running at least 3 VMs for testing
- **Dependencies**: Docker installed

### Multiple Nodes Setup (Master and Agents):
- **Operating System**: Linux on all nodes
- **Resources**: 
  - Master: at least 2 CPUs, 16 GB of memory, and sufficient storage (e.g, ~20 GBs for the retention of some days of honeypot logs)
  - Agents: similar to master
- **Dependencies**: See the installation scripts in [k3s-ansible/README.md](k3s-ansible/README.md)

## Deployment

### Set Up Hosts
```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --ask-vault-password
```

### Deploy Local Registry
```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy_registry.yml 
```

### Build and Push Images
```bash
ansible-playbook -i inventory/hosts.yml playbooks/build_and_push_images.yml 
```

### Install/Uninstall Applications
Refer to `host.yml` to define which applications to deploy.
- To install applications:
  ```bash
  ansible-playbook -i inventory/hosts.yml playbooks/deploy_applications.yml
  ```
- To uninstall applications:
  ```bash
  ansible-playbook -i inventory/hosts.yml playbooks/deploy_applications.yml -e "action=remove"
  ```

---
<<<<<<< HEAD

### Deploy scripts for data sync
```bash
ansible-playbook -i inventory/hosts.yml playbooks/set_data_sync.yml
```

# Provisioning VMs for the Testing Environment
=======
## Provisioning VMs for the Testing Environment
>>>>>>> aec0cee (updating the readme files)

See [vm-provisioning/README.md](vm-provisioning/README.md)

---
## WireGuard and K3s Installation

See [k3s-ansible/README.md](k3s-ansible/README.md)


## Maintainers

- Rodolfo Vieira Valentim
- Andrea Sordello
- Idilio Drago
- Alejandro Ayala Gil 
