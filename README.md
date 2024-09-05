# K3s Cluster with WireGuard for Security Monitoring

This project sets up a K3s cluster to deploy network probes (such as honeypots) for monitoring and analyzing potential security threats. The cluster consists of a master node and multiple agent nodes, all connected via WireGuard VPN.

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

