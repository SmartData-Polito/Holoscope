#!/bin/bash

# Exit on any error
set -e

# Update and install dependencies
echo "Updating package lists and installing dependencies..."
sudo apt-get update
sudo apt-get install -y curl git build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev wget llvm \
libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev \
python-openssl libedit-dev

# Install pyenv using curl
echo "Installing pyenv..."
curl https://pyenv.run | bash

# Add pyenv to bashrc so that it's available in future shell sessions
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc

# Apply the changes to current session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# Install Ansible
echo "Installing Ansible via pyenv..."
pyenv install 3.11.5  # You can change this to any version of Python
pyenv global 3.11.5
pip install --upgrade pip
pip install ansible

# Verify installation
echo "Verifying installations..."
pyenv --version
ansible --version

echo "Setup complete. Pyenv and Ansible are installed."
