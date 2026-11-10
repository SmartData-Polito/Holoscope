#!/bin/bash
set -e

echo "=== Collector-Sync Capture Service Starting ==="

# Detect environment
detect_environment() {
    if [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
        echo "kubernetes"
    else
        echo "docker-compose"
    fi
}

# Environment-specific data directory setup
setup_data_directory() {
    local env=$(detect_environment)
    
    echo "Setting up data directory for environment: $env"
    mkdir -p /data/darknet 
    chown capture:capture /data/darknet
}


# Start packet capture
start_packet_capture() {
    local env=$(detect_environment)
    
    # Set default values for environment variables

    FILTER=${FILTER:-ip}
    ROTATE_SECONDS=${ROTATE_SECONDS:-60}

    echo "=== Starting Packet Capture ==="
    echo "Environment: $env"
    echo "Interface: $INTERFACES"
    echo "Filter: $FILTER"
    echo "Rotation: $ROTATE_SECONDS seconds"
    echo "Output: /data/darknet/"

    # Cleanup function
    cleanup() {
        echo "Shutting down..."
        kill $SSH_PID 2>/dev/null || true
        exit 0
    }

    trap cleanup SIGTERM SIGINT

    # Start dumpcap in background
    su - capture -c "dumpcap \
        -b duration:$ROTATE_SECONDS \
        -w \"/data/darknet/trace.pcap\" \
        -f \"$FILTER\" \
        $INTERFACES " &

    DUMPCAP_PID=$!  
    echo "Packet capture started with PID: $DUMPCAP_PID"
    wait $DUMPCAP_PID
}

# Main execution flow
main() {
    local env=$(detect_environment)
    echo "Detected environment: $env"
    
    setup_data_directory
    start_packet_capture
}

# Run main function
main