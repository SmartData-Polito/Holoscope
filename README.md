# CyBorg – Distributed Edge Platform for Cybersecurity Data Collection and Machine Learning

## Overview

**CyBorg** is a distributed edge platform designed for both cybersecurity data collection and machine learning applications. The project aims to create an extensive testbed for deploying and exploiting vulnerable applications. The platform operates in two main capacities:

1. **Testbed for Vulnerabilities**: CyBorg allows for the deployment of vulnerable applications, which can be exploited by both internal and external agents. These scenarios provide rich data for testing security mechanisms and understanding the behavior of different types of cyber-attacks.
    
2. **Data Collection Platform**: CyBorg is equipped with powerful crawlers to monitor activity on the darknet and other cybersecurity-relevant platforms. The collected data is then utilized for machine learning models to identify threats, vulnerabilities, and trends in cybersecurity.
    

This platform is lightweight, stable, and scalable, utilizing [K3s](https://k3s.io/) for Kubernetes management and [Ansible](https://www.ansible.com/) for automation of the deployment and configuration processes. CyBorg provides an efficient environment for simulating real-world cybersecurity attacks and data collection for further analysis.

---

## Why the Name **CyBorg**?

The name **CyBorg** is inspired by the **Borg**, a collective race from the _Star Trek_ universe. The Borg are known for their interconnected, hive-mind system where each individual unit contributes to the greater whole. Similarly, **CyBorg** reflects the idea of multiple distributed nodes working together to form a powerful, collective platform for cybersecurity.

While **"Cy"** stands for **Cybersecurity**, **"Borg"** signifies the distributed and collective intelligence behind the platform, much like the _Star Trek_ Borg. This distributed nature enables the platform to gather data and defend against threats in a unified, cohesive way.

---

## Key Features

- **Distributed Edge Nodes**: CyBorg operates at the edge, allowing cybersecurity monitoring and data collection from a variety of distributed nodes.
- **Vulnerability Testbed**: Deploy and exploit vulnerable applications in a controlled environment to simulate real-world attack scenarios.
- **Data Collection**: Leverages crawlers and monitoring tools to gather data from various sources, including the darknet, for further analysis.
- **Lightweight Kubernetes**: Utilizes K3s for a reliable, lightweight Kubernetes implementation, making the platform scalable and easy to manage.
- **Ansible Automation**: The entire platform is managed by Ansible, simplifying deployments, updates, and configuration across distributed nodes.

---

## Architecture

- **K3s**: A lightweight Kubernetes distribution for running services on edge nodes.
- **Ansible**: Automation tool for managing deployment and configuration.
- **Data Crawlers**: Custom crawlers to collect data from darknet and other cybersecurity sources.
- **Testbed Applications**: A variety of vulnerable applications to be deployed and exploited by internal/external agents.
## Prerequisites

### Single Node Setup:
- **Operating System**: Linux (e.g., Ubuntu 20.04)
- **Resources**: Adequate CPU and memory for running at least 3 VMs for testing
- **Dependencies**: Docker installed

### Multiple Nodes Setup (Master and Agents):
- **Operating System**: Linux (e.g., Ubuntu 20.04) on all nodes
- **Resources**: 
  - Master: at least 2 CPUs, 16 GB of memory, and sufficient storage (e.g, ~20 GBs for the retention of some days of honeypot logs)
  - Agents: similar to master
- **Dependencies**: See the installation scripts in [k3s-ansible/README.md](k3s-ansible/README.md)

## Deployment

### Set Up Hosts:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --ask-vault-password --ask-become-pass
```

### Deploy Local Registry:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy_registry.yml --ask-vault-password --ask-become-pass
```

### Build and Push Images:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/build_and_push_images.yml --ask-vault-password --ask-become-pass
```

### Install/Uninstall Applications:
Refer to `host.yml` to define which applications to deploy.
- To install applications:
  ```bash
  ansible-playbook -i inventory/hosts.yml playbooks/deploy_applications.yml --ask-become-pass
  ```
- To uninstall applications:
  ```bash
  ansible-playbook -i inventory/hosts.yml playbooks/deploy_applications.yml -e "action=remove"
  ```

---

# Provisioning VMs for the Testing Environment

See [vm-provisioning/README.md](vm-provisioning/README.md)

---

# WireGuard and K3s Installation

See [k3s-ansible/README.md](k3s-ansible/README.md)


<!-- 
# Maintainers & Contributors
TODO: Complete here
 -->

