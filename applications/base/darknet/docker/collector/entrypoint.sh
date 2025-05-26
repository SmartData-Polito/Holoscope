#!/bin/bash
set -euo pipefail

echo "Starting Darknet Collector for Kubernetes"

# Kubernetes-specific environment validation
validate_k8s_env() {
    local missing_vars=()
    
    # Required Kubernetes environment variables
    [[ -z "${WORKER_NODES:-}" ]] && missing_vars+=("WORKER_NODES")
    [[ -z "${SSH_USERS:-}" ]] && missing_vars+=("SSH_USERS") 
    [[ -z "${SOURCE_PATH:-}" ]] && missing_vars+=("SOURCE_PATH")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "Missing required environment variables: ${missing_vars[*]}"
        echo "This collector is configured for Kubernetes deployment."
        echo "Please ensure the following variables are set:"
        echo "  WORKER_NODES, SSH_USERS, SOURCE_PATH"
        exit 1
    fi
}

# Setup SSH configuration for Kubernetes
setup_k8s_ssh() {
    echo "Setting up SSH for Kubernetes environment"
    
    # SSH key should be mounted from Kubernetes secret
    if [[ -f "/etc/ssh-keys/id_rsa" ]]; then
        cp /etc/ssh-keys/id_rsa /home/collector/.ssh/
        chmod 600 /home/collector/.ssh/id_rsa
        chown collector:collector /home/collector/.ssh/id_rsa
        echo "SSH key loaded from Kubernetes secret"
    else
        echo "SSH key not found at /etc/ssh-keys/id_rsa"
        echo "Please ensure the SSH secret is properly mounted"
        exit 1
    fi
    
    # Setup SSH config for non-interactive use
    cat > /home/collector/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    chown collector:collector /home/collector/.ssh/config
    chmod 600 /home/collector/.ssh/config
}

# Kubernetes readiness probe support
create_readiness_indicator() {
    echo "Creating readiness indicator"
    echo "ready" > /tmp/collector-ready
    echo "Collector ready for Kubernetes probes"
}

# Kubernetes-specific node discovery
discover_k8s_nodes() {
    echo "Discovering Kubernetes worker nodes"
    
    # Convert space-separated to arrays
    IFS=' ' read -ra NODES <<< "${WORKER_NODES}"
    IFS=' ' read -ra USERS <<< "${SSH_USERS}"
    
    echo "Configuration:"
    echo "  Worker Nodes: ${WORKER_NODES}"
    echo "  SSH Users: ${SSH_USERS}"
    echo "  Source Path: ${SOURCE_PATH}"
    echo "  Destination Path: ${DEST_PATH:-/data/collector}"
    echo "  Collection Interval: ${COLLECTION_INTERVAL:-3600}s"
    
    # Validate arrays match
    if [[ ${#NODES[@]} -ne ${#USERS[@]} ]]; then
        echo "Mismatch: ${#NODES[@]} nodes but ${#USERS[@]} users"
        exit 1
    fi
    
    echo "Configuration validated"
}

# Pre-populate known hosts to avoid SSH prompts
setup_known_hosts() {
    echo "Setting up known hosts for SSH"
    
    IFS=' ' read -ra NODES <<< "${WORKER_NODES}"
    for node in "${NODES[@]}"; do
        echo "Adding $node to known hosts..."
        ssh-keyscan -H "$node" >> /home/collector/.ssh/known_hosts 2>/dev/null || {
            echo "Warning: Could not scan $node (may be normal during startup)"
        }
    done
    chown collector:collector /home/collector/.ssh/known_hosts
}

# Main entrypoint logic
main() {
    echo "Kubernetes Collector Entrypoint"
    
    # Run all setup functions
    validate_k8s_env
    setup_k8s_ssh
    discover_k8s_nodes
    setup_known_hosts
    create_readiness_indicator
    
    echo "Setup complete, starting collector..."
    echo "----------------------------------------"
    
    # Execute the main command (collector.sh)
    exec "$@"
}

# Handle signals gracefully for Kubernetes
trap 'echo "Received shutdown signal"; exit 0' SIGTERM SIGINT

# Run main function
main "$@"