#!/bin/bash

# Exit on any error
set -e

# Update and install system dependencies
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y ansible python3 python3-venv python3-pip && \
python3 -m pip install --user pipx && \
python3 -m pipx ensurepath

# Create a virtual environment for additional packages
echo "Creating virtual environment for Python packages..."
python3 -m venv ~/ansible-env

# Activate the virtual environment
source ~/ansible-env/bin/activate

# Install additional Python packages in the virtual environment
echo "Installing additional Python packages..."
pip install --upgrade pip
pip install passlib

# Add activation shortcut to bashrc
echo 'alias ansible-env="source ~/ansible-env/bin/activate"' >> ~/.bashrc

# Install Ansible collection (works with system Ansible)
echo "Installing Ansible collections..."
ansible-galaxy collection install ansible.posix

# Verify installation
echo "Verifying installation..."
ansible --version
echo "Python packages installed in virtual environment: ~/ansible-env"

echo "Setup complete. Ansible is installed."
echo "To activate the Python environment in new sessions, run: source ~/ansible-env/bin/activate"
echo "Or use the alias: ansible-env"

# Setup the VMs
vagrant up

cd ../ansible

# Run the Ansible playbook to configure the VMs
echo "Running Ansible playbook to configure VMs..."
ansible-playbook -i inventory/environments/dev/hosts.yml playbooks/site.yml
ansible-playbook -i inventory/environments/dev/hosts.yml playbooks/registry.yml
ansible-playbook -i inventory/environments/dev/hosts.yml playbooks/build.yml
ansible-playbook -i inventory/environments/dev/hosts.yml playbooks/deploy.yml