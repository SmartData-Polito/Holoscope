# Setting Up a Testing Environment with Vagrant and Libvirt

This section explains how to set up a testing environment that mirrors production, using Vagrant and Libvirt on a pre-configured `honeynet` network.

## Prerequisites

Before starting, ensure the following are installed and configured:
- **Libvirt** 
- **Vagrant**
- A pre-configured `honeynet.xml` file for the honeynet network

## Environment Setup

### 1. Create the Honeynet Network
Use `virsh` to create the honeynet network from the XML configuration file:
```bash
virsh net-create honeynet.xml
```

### 2. Start the Vagrant Environment
Once the honeynet network is running, bring up the Vagrant environment:
```bash
vagrant up
```

## Tearing Down the Environment

### 1. Destroy Vagrant VMs
To clean up, first destroy the Vagrant VMs:
```bash
vagrant destroy -f
```

### 2. Destroy the Honeynet Network
Then, stop and remove the honeynet network:
```bash
virsh net-destroy honeynet
```
