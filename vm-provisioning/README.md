# Vagrant Environment for Honeynet Network Setup

This project sets up a virtualized environment using Vagrant, Libvirt, and VirtualBox, creating virtual nodes for a honeynet testing environment. The configuration supports multiple operating systems (Linux, macOS, and Windows) and uses Ansible for provisioning.

## Prerequisites

Before running this setup, ensure the following software is installed on your machine:

1. **Vagrant** - Vagrant is a tool for building and managing virtual machine environments.
2. **Libvirt** (for Linux) - A toolkit to interact with the virtualization capabilities of Linux systems.
3. **VirtualBox** (for macOS and Windows) - A cross-platform hypervisor that allows you to run virtual machines on your local system.
4. **Ansible** - An open-source IT automation engine, required for provisioning.
5. **Pre-configured Honeynet Network XML**  (for production compatibility) - Ensure you have a valid `honeynet.xml` file to set up the network.

### Installing Prerequisites

1. **Install Vagrant**:
   - [Vagrant Installation Instructions](https://developer.hashicorp.com/vagrant/docs/installation)

2. **Install Libvirt (Linux)**:
    ```bash
    sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients ebtables dnsmasq-base
    sudo apt-get install vagrant-libvirt
    ```

3. **Install VirtualBox (macOS/Windows)**:
   - [VirtualBox Installation Instructions](https://www.virtualbox.org/wiki/Downloads)

4. **Install Pyenv and Ansible using the helper script**:
    ```bash
    chmod +x ./setup_development_node.sh
    ./setup_development_node.sh
    ```

## Setup Instructions

### Step 1: Create Honeynet Network (Linux)

Create the honeynet network using the provided `honeynet.xml` file.

```bash
virsh net-create honeynet.xml
```

Ensure that the network is active:

```bash
virsh net-list
```
This will list all active networks. Make sure that the honeynet is up and running.

### Step 2: Configure Environment Variables
Set the Vagrant configuration file path: You can define an external configuration file (XML format) by setting the CONFIG_FILE environment variable. If no configuration file is provided, default nodes will be used. This is valid for production compatibility, since the network configuration for the host are defined via DHCP. 

```bash
export CONFIG_FILE="/path/to/your/network/config.xml"
```

Set the Ansible playbook (optional): If you want to use a specific Ansible playbook, define it using the ANSIBLE_PLAYBOOK environment variable:

```bash
export ANSIBLE_PLAYBOOK="/path/to/your/playbook.yml"
```

If no playbook is provided, basicsetup.yml will be used by default.

### Step 3: Start the Vagrant Environment
Run the following command to start up the Vagrant environment:

```bash
vagrant up
```
The Vagrantfile will automatically detect your host operating system and configure the environment using either Libvirt (Linux) or VirtualBox (macOS/Windows).

### Step 4: Verify the Setup
Once Vagrant has finished setting up the environment, you can verify that the VMs are running and provisioned correctly using:

```bash
vagrant status
```
### Step 5: Access the Virtual Machines
To SSH into a specific node (e.g., the master node), run:

```bash
vagrant ssh master-00
```
## Tearing Down the Environment

### Step 1: Destroy the Vagrant VMs
To clean up the virtual machines:

```bash
vagrant destroy -f
```
### Step 2: Destroy the Honeynet Network (Linux)
To stop and remove the honeynet network:

```bash
virsh net-destroy honeynet
```
## Customizing Nodes and Network
To customize the virtual machines and network settings, modify the Vagrantfile or provide a custom XML configuration file with your node definitions.

## Troubleshooting
**Libvirt issues:** If you're using Libvirt and encounter issues with network setup, ensure that the honeynet.xml is valid and the network is created successfully.
**VirtualBox GUI:** On macOS and Windows, VirtualBox may launch a GUI for each VM. You can disable the GUI by modifying the Vagrantfile.