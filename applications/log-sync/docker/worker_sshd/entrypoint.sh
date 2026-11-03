#!/bin/bash
set -e

echo "=== Log-Sync SSHD Service Starting ==="

detect_environment() {
    if [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
        echo "kubernetes"
    else
        echo "docker-compose"
    fi
}

setup_ssh_keys() {
    local environment
    environment=$(detect_environment)

    echo "Setting up SSH keys for environment: $environment"

    local pubkey_path="/etc/ssh-keys/id_rsa.pub"
    local alternative_path="/var/secrets/ssh/id_rsa.pub"
    local timeout=60
    local counter=0

    echo "Waiting for SSH public key..."

    while true; do
        if [[ -f "$pubkey_path" ]]; then
            break
        fi

        if [[ "$environment" == "kubernetes" &&
              -f "$alternative_path" ]]; then
            pubkey_path="$alternative_path"
            break
        fi

        if (( counter >= timeout )); then
            echo "ERROR: Timeout waiting for SSH public key after ${timeout} seconds" >&2
            echo "Checked: $pubkey_path" >&2

            if [[ "$environment" == "kubernetes" ]]; then
                echo "Checked: $alternative_path" >&2
            fi

            exit 1
        fi

        sleep 1
        counter=$((counter + 1))
    done

    echo "SSH public key found after ${counter} seconds at: $pubkey_path"

    if [[ ! -s "$pubkey_path" ]]; then
        echo "ERROR: SSH public key file is empty: $pubkey_path" >&2
        exit 1
    fi

    if ! id capture >/dev/null 2>&1; then
        echo "Creating capture user..."
        adduser -D -s /bin/bash capture
    fi

    echo "Setting up SSH public key for capture user..."

    mkdir -p /home/capture/.ssh
    cp "$pubkey_path" /home/capture/.ssh/authorized_keys

    chown capture:capture /home/capture
    chown -R capture:capture /home/capture/.ssh

    chmod 700 /home/capture/.ssh
    chmod 600 /home/capture/.ssh/authorized_keys

    echo "SSH public key configured successfully"
}

setup_data_directory() {
    echo "Setting up data directory..."

    mkdir -p /data/darknet
    chown capture:capture /data/darknet
}

start_ssh_daemon() {
    local sshd_opts=(-D -e -p 65222)

    mkdir -p /run/sshd

    # Generate missing server host keys.
    ssh-keygen -A

    if [[ -n "${SSH_LISTEN_ADDRESS:-}" ]]; then
        echo "Configuring SSH to listen on: $SSH_LISTEN_ADDRESS"
        sshd_opts+=(-o "ListenAddress=$SSH_LISTEN_ADDRESS")
    fi

    echo "Validating SSH daemon configuration..."
    /usr/sbin/sshd -t "${sshd_opts[@]}"

    echo "Starting SSH daemon on ${SSH_LISTEN_ADDRESS:-all addresses}:65222..."

    # Replace the shell so SSH remains the container's main process.
    exec /usr/sbin/sshd "${sshd_opts[@]}"
}

main() {
    local environment
    environment=$(detect_environment)

    echo "Detected environment: $environment"

    setup_ssh_keys
    setup_data_directory
    start_ssh_daemon
}

main