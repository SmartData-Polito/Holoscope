# Provisioning VMs for the Testing Environment

Set up and manage a testing environment that mirrors the production network. The environment uses Vagrant with Libvirt on a pre-configured `honeynet` network.

## Prerequisites

- **Libvirt** installed and configured
- **Vagrant** installed
- Pre-configured `libvirt_honeynet.xml` file

## Setup

### Create the Environment

1. **Create the Honeynet Network:**

```bash 
$ virsh net-create libvirt_honeynet.xml
```

2. Start the Vagrant Environment:

```bash 
$ vagrant up
```

### Destroy the Environment

1. Destroy Vagrant VMs:

```bash 
$ vagrant destroy -f
```

2. Destroy the Honeynet Network:

```bash 
$ virsh net-destroy honeynet
```