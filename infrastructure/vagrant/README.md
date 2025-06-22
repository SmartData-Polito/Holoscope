# Vagrant Environment for Honeynet Network Setup

This project sets up a virtualized environment using Vagrant, creating virtual nodes for a honeynet development environment. The configuration supports multiple operating systems (Linux, macOS, and Windows) and uses Ansible for provisioning.

## Default Node Configuration

When no custom configuration is provided, the following nodes are created:
- **master-00**: 10.10.0.100 (Ubuntu 22.04)
- **worker-00**: 10.10.0.101 (Ubuntu 22.04)  
- **worker-01**: 10.10.0.102 (Ubuntu 22.04)

Each node defaults to 2 CPUs and 2048 MB RAM.

## Prerequisites

Before running this setup, ensure the following software is installed on your machine:

1. **Vagrant** - Tool for building and managing virtual machine environments
2. **Libvirt** (for Linux) - Virtualization toolkit for Linux systems
3. **VirtualBox** (for macOS and Windows) - Cross-platform hypervisor
4. **Ansible** (Linux/macOS only) - IT automation engine for provisioning

### Installing Prerequisites

1. **Install Vagrant**:
   - [Vagrant Installation Instructions](https://developer.hashicorp.com/vagrant/docs/installation)

2. **Install Libvirt (Linux only)**:
   ```bash
   sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients ebtables dnsmasq-base
   sudo apt-get install vagrant-libvirt
   ```

3. **Install VirtualBox (macOS/Windows)**:
   - [VirtualBox Installation Instructions](https://www.virtualbox.org/wiki/Downloads)

4. **Quick Setup with Included Script (Linux)**:
   ```bash
   chmod +x ./install.sh
   ./install.sh
   ```
   
   This script installs:
   - Ansible and Python dependencies
   - Creates a Python virtual environment at `~/ansible-env`
   - Installs required Ansible collections
   - Automatically runs `vagrant up` to start the environment

## Environment Variables

Customize your setup using these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `CONFIG_FILE` | Path to XML configuration file | None (uses hardcoded nodes) |
| `ANSIBLE_PLAYBOOK` | Path to Ansible playbook | `basicsetup.yml` |
| `NODE_CPUS` | CPU count per node | `2` |
| `NODE_MEMORY` | Memory per node (MB) | `2048` |

### Example Configuration
```bash
export CONFIG_FILE="/path/to/your/network/config.xml"
export ANSIBLE_PLAYBOOK="/path/to/your/playbook.yml"
export NODE_CPUS=4
export NODE_MEMORY=4096
```

## Setup Instructions

### Option 1: Quick Setup (Linux)
```bash
chmod +x ./install.sh
./install.sh
```
This script handles all dependencies and automatically starts the environment.

### Option 2: Manual Setup

#### Step 1: Configure Environment Variables (Optional)
Set any desired environment variables as shown above.

#### Step 2: Start the Vagrant Environment
```bash
vagrant up
```
The Vagrantfile automatically detects your host OS and configures appropriately:
- **Linux**: Uses Libvirt with custom honeynet network
- **macOS**: Uses VirtualBox with MAC address assignment
- **Windows**: Uses VirtualBox with IP assignment (Ansible disabled)

#### Step 3: Verify the Setup
```bash
vagrant status
```

#### Step 4: Access Virtual Machines
```bash
vagrant ssh master-00
# or
vagrant ssh worker-00
```

## Platform-Specific Notes

### Linux
- Uses Libvirt provider for better performance
- Requires `honeynet.xml` file for network definition
- Full Ansible provisioning support
- Creates custom "honeynet" network

### macOS
- Uses VirtualBox provider
- Assigns MAC addresses to VMs
- Full Ansible provisioning support
- VMs may launch with GUI (can be disabled)

### Windows
- Uses VirtualBox provider  
- Assigns static IP addresses
- Ansible provisioning is disabled
- VMs launch with GUI enabled

## Custom XML Configuration

To use a custom node configuration, create an XML file with this structure:
```xml
<network>
  <ip>
    <dhcp>
      <host name="custom-node" mac="00:00:00:00:00:FF" ip="10.10.0.200"/>
      <!-- Add more hosts as needed -->
    </dhcp>
  </ip>
</network>
```

Then set: `export CONFIG_FILE="/path/to/your/config.xml"`

## Managing the Environment

### View Status
```bash
vagrant status
```

### SSH into Nodes
```bash
vagrant ssh <node-name>
```

### Restart Nodes
```bash
vagrant reload
```

### Update Provisioning
```bash
vagrant provision
```

## Tearing Down the Environment

### Destroy VMs
```bash
vagrant destroy -f
```

### Clean Up Network (Linux with Libvirt)
```bash
virsh net-destroy honeynet
virsh net-undefine honeynet
```

