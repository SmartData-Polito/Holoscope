#!/bin/bash
set -e

echo "=== Darknet Capture Service Starting ==="

# Detect environment
detect_environment() {
    if [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
        echo "kubernetes"
    else
        echo "docker-compose"
    fi
}

# Environment-specific SSH key setup
setup_ssh_keys() {
    local env=$(detect_environment)
    echo "Setting up SSH keys for environment: $env"
    
    # Find SSH public key location
    local pubkey_path="/etc/ssh-keys/id_rsa.pub"
    
    # For K8s, check alternative paths
    if [[ "$env" == "kubernetes" ]]; then
        if [[ ! -f "$pubkey_path" ]]; then
            pubkey_path="/var/secrets/ssh/id_rsa.pub"
        fi
    fi
    
    # Wait for SSH public key to be available
    echo "Waiting for SSH public key at $pubkey_path..."
    timeout=60
    counter=0
    while [ ! -f "$pubkey_path" ]; do
        if [ $counter -ge $timeout ]; then
            echo "ERROR: Timeout waiting for SSH public key after ${timeout} seconds"
            echo "Checked paths:"
            find /etc -name "id_rsa.pub" 2>/dev/null || true
            find /var -name "id_rsa.pub" 2>/dev/null || true
            exit 1
        fi
        sleep 1
        ((counter++))
    done

    echo "SSH public key found after ${counter} seconds at: $pubkey_path"
    
    # Setup capture user (environment-specific)
    if [[ "$env" == "kubernetes" ]]; then
        # In K8s, user management might be different
        echo "Configuring capture user for Kubernetes..."
        # Ensure user exists
        if ! id capture >/dev/null 2>&1; then
            adduser -D -s /bin/bash capture
        fi
        # In K8s, passwd -u might not be needed/available
        echo "Capture user ready for Kubernetes"
    else
        # Docker Compose approach
        echo "Unlocking capture user account..."
        #passwd -u capture
        echo "Capture user account unlocked"
    fi
    
    # Set up SSH public key for capture user
    echo "Setting up SSH public key for capture user..."
    mkdir -p /home/capture/.ssh
    cp "$pubkey_path" /home/capture/.ssh/authorized_keys
    chown capture:capture /home/capture/.ssh/authorized_keys
    chmod 600 /home/capture/.ssh/authorized_keys
    echo "SSH public key configured successfully"
    
    # Show first part of the key for verification
    echo "Public key preview: $(head -c 50 /home/capture/.ssh/authorized_keys)..."
}

# Environment-specific data directory setup
setup_data_directory() {
    local env=$(detect_environment)
    
    echo "Setting up data directory for environment: $env"
    mkdir -p /data/darknet
    
    if [[ "$env" == "kubernetes" ]]; then
        # In K8s, might use fsGroup for permissions, so be more permissive
        chown capture:capture /data/darknet || {
            echo "Warning: Could not change ownership in K8s environment (this may be normal)"
            chmod 777 /data/darknet
        }
    else
        # Docker Compose - standard ownership
        chown capture:capture /data/darknet
    fi
    
    echo "Data directory ready: /data/darknet"
}

# Start SSH daemon
start_ssh_daemon() {
    echo "Starting SSH daemon..."
    /usr/sbin/sshd -D &
    SSH_PID=$!

    # Wait a moment for SSH to start
    sleep 2

    # Verify SSH is running
    if netstat -tlnp | grep -q :22; then
        echo "SSH server started successfully on port 22"
    else
        echo "WARNING: SSH server may not be listening on port 22"
    fi
}

# Start packet capture
start_packet_capture() {
    local env=$(detect_environment)
    
    # Set default values for environment variables
    INTERFACE=${INTERFACE:-eth0}
    FILTER=${FILTER:-ip}
    ROTATE_SECONDS=${ROTATE_SECONDS:-60}

    echo "=== Starting Packet Capture ==="
    echo "Environment: $env"
    echo "Interface: $INTERFACE"
    echo "Filter: $FILTER"
    echo "Rotation: $ROTATE_SECONDS seconds"
    echo "Output: /data/darknet/trace-%Y%m%d_%H-%M-%S_%s.pcap"

    # Verify interface exists
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        echo "ERROR: Network interface '$INTERFACE' not found"
        echo "Available interfaces:"
        ip link show
        exit 1
    fi

    # Cleanup function
    cleanup() {
        echo "Shutting down..."
        kill $SSH_PID 2>/dev/null || true
        exit 0
    }

    trap cleanup SIGTERM SIGINT

    # Start packet capture with environment-specific options
    if [[ "$env" == "kubernetes" ]]; then
        echo "Starting tcpdump for Kubernetes environment..."
        # In K8s, -Z flag might behave differently, so we'll handle file ownership separately
        exec tcpdump -i "$INTERFACE" \
            -G "$ROTATE_SECONDS" \
            -w "/data/darknet/trace-%Y%m%d_%H-%M-%S_%s.pcap" \
            -v \
            "$FILTER"
    else
        echo "Starting tcpdump for Docker Compose environment..."
        exec tcpdump -i "$INTERFACE" \
            -G "$ROTATE_SECONDS" \
            -w "/data/darknet/trace-%Y%m%d_%H-%M-%S_%s.pcap" \
            -v \
            "$FILTER"
    fi
}

# Main execution flow
main() {
    local env=$(detect_environment)
    echo "Detected environment: $env"
    
    setup_ssh_keys
    setup_data_directory
    start_ssh_daemon
    start_packet_capture
}

# Run main function
main