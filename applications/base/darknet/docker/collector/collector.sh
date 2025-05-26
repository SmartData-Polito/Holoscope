#!/bin/bash
#
# Kubernetes-Native PCAP Collector
# Optimized for Kubernetes deployment with proper signal handling
#

set -euo pipefail

# Kubernetes environment defaults
DEST_PATH=${DEST_PATH:-"/data/collector"}
COLLECTION_INTERVAL=${COLLECTION_INTERVAL:-3600}
LOG_LEVEL=${LOG_LEVEL:-"INFO"}

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

# Signal handler for graceful shutdown
shutdown_handler() {
    log "INFO" "Received shutdown signal, finishing current collection..."
    exit 0
}

# Trap signals for Kubernetes
trap 'shutdown_handler' SIGTERM SIGINT

# Health check function (for Kubernetes probes)
health_check() {
    if [[ -f /tmp/collector-ready ]]; then
        return 0
    else
        return 1
    fi
}

# Collection function for a single node
collect_from_node() {
    local node="$1"
    local user="$2"
    local node_dest="${DEST_PATH}/${node}"
    
    log "INFO" "Collecting from $node as $user"
    
    # Create node-specific directory
    mkdir -p "$node_dest"
    
    # Resolve node IP (Kubernetes DNS or fallback)
    local node_ip
    if getent hosts "$node" &>/dev/null; then
        node_ip=$(getent hosts "$node" | awk '{print $1}')
        log "DEBUG" "Resolved $node to $node_ip"
    else
        node_ip="$node"
        log "WARN" "Could not resolve $node, using as-is"
    fi
    
    # Find most recent file to exclude (avoid incomplete captures)
    local exclude_file
    exclude_file=$(ssh -i /home/collector/.ssh/id_rsa "${user}@${node_ip}" \
        "ls -t ${SOURCE_PATH}/ 2>/dev/null | grep -E '\.pcap$' | head -n1" || echo "")
    
    local exclude_option=""
    if [[ -n "$exclude_file" ]]; then
        exclude_option="--exclude=$exclude_file"
        log "DEBUG" "Excluding most recent file: $exclude_file"
    fi
    
    # Rsync with proper error handling
    log "INFO" "Syncing from ${user}@${node_ip}:${SOURCE_PATH}/"
    
    if rsync -azP --mkpath $exclude_option \
        -e "ssh -i /home/collector/.ssh/id_rsa" \
        "${user}@${node_ip}:${SOURCE_PATH}/*.pcap" "$node_dest/" 2>/dev/null; then
        log "INFO" "Successfully collected from $node"
    else
        log "WARN" "rsync from $node failed (exit code $?)"
        return 1
    fi
    
    # Organize files by date structure
    organize_files "$node_dest" "$node"
}

# Organize PCAP files by date
organize_files() {
    local node_dest="$1"
    local node="$2"
    
    log "DEBUG" "Organizing files for $node"
    
    pushd "$node_dest" >/dev/null
    
    # Process all PCAP files
    find . -maxdepth 1 -name "*.pcap" -type f | while IFS= read -r filepath; do
        local filename
        filename=$(basename "$filepath")
        
        # Match expected filename pattern: trace-YYYYMMDD_HH-MM-SS_NUMBER.pcap
        # or node-specific: worker-XX-trace-YYYYMMDD_HH-MM-SS_NUMBER.pcap
        local date_pattern="([0-9]{8})_([0-9]{2})-([0-9]{2})-([0-9]{2})"
        
        if [[ $filename =~ $date_pattern ]]; then
            local date_part="${BASH_REMATCH[1]}"
            local year="${date_part:0:4}"
            local month="${date_part:4:2}"
            local day="${date_part:6:2}"
            
            # Create year/month/day directory structure
            mkdir -p "$year/$month/$day"
            mv "$filepath" "$year/$month/$day/"
            log "DEBUG" "Organized $filename -> $year/$month/$day/"
        else
            log "WARN" "Unknown filename pattern: $filename (skipping organization)"
        fi
    done
    
    popd >/dev/null
}

# Main collection loop
main_collection_loop() {
    log "INFO" "Starting Kubernetes PCAP Collector"
    log "INFO" "Config: ${WORKER_NODES} | Interval: ${COLLECTION_INTERVAL}s"
    
    # Convert environment variables to arrays
    IFS=' ' read -ra NODES <<< "${WORKER_NODES}"
    IFS=' ' read -ra USERS <<< "${SSH_USERS}"
    
    while true; do
        log "INFO" "Starting collection cycle"
        local cycle_start=$(date +%s)
        
        # Collect from each node
        for i in "${!NODES[@]}"; do
            collect_from_node "${NODES[$i]}" "${USERS[$i]}" || {
                log "ERROR" "Failed to collect from ${NODES[$i]}"
            }
        done
        
        local cycle_end=$(date +%s)
        local cycle_duration=$((cycle_end - cycle_start))
        
        log "INFO" "Collection cycle completed in ${cycle_duration}s"
        log "INFO" "Sleeping for ${COLLECTION_INTERVAL}s..."
        
        # Sleep with signal handling
        sleep "${COLLECTION_INTERVAL}" &
        wait $!
    done
}

# Handle special commands
case "${1:-}" in
    "health")
        health_check && echo "healthy" || echo "unhealthy"
        exit $?
        ;;
    "version")
        echo "Darknet Collector v1.0.0 (Kubernetes-native)"
        exit 0
        ;;
    *)
        # Run main collection loop
        main_collection_loop
        ;;
esac