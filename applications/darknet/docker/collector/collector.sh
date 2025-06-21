#!/bin/bash
set -euo pipefail

# Configuration
WORKER_NODE=${WORKER_NODE:-}
SSH_USER=${SSH_USER:-}
SOURCE_PATH=${SOURCE_PATH:-"/data/darknet"}
DEST_PATH=${DEST_PATH:-"/data/collector"}
COLLECTION_INTERVAL=${COLLECTION_INTERVAL:-3600}
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
RUN_MODE=${RUN_MODE:-"daemon"}  # "daemon" for docker-compose, "cronjob" for k8s

# Logging
log() {
    local level=$1
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        DEBUG) [[ "$LOG_LEVEL" == "DEBUG" ]] && echo "[$timestamp] [DEBUG] $*" ;;
        INFO)  echo "[$timestamp] [INFO] $*" ;;
        WARN)  echo "[$timestamp] [WARN] $*" ;;
        ERROR) echo "[$timestamp] [ERROR] $*" >&2 ;;
    esac
}

# Validate required variables
validate_env() {
    if [[ -z "$WORKER_NODE" ]] || [[ -z "$SSH_USER" ]]; then
        log "ERROR" "WORKER_NODE and SSH_USER environment variables are required"
        exit 1
    fi
}

# Setup SSH
setup_ssh() {
    log "INFO" "Setting up SSH configuration"
    
    local ssh_key="/etc/ssh-keys/id_rsa"
    if [[ ! -f "$ssh_key" ]]; then
        log "ERROR" "SSH private key not found at $ssh_key"
        exit 1
    fi
    
    mkdir -p /root/.ssh
    cp "$ssh_key" /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
    
    cat > /root/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ConnectTimeout 15
    IdentityFile /root/.ssh/id_rsa
    BatchMode yes
    PasswordAuthentication no
    PubkeyAuthentication yes
EOF
    chmod 600 /root/.ssh/config
}

# Test SSH connection
test_ssh() {
    log "INFO" "Testing SSH connection to $SSH_USER@$WORKER_NODE"
    if ssh "$SSH_USER@$WORKER_NODE" 'echo "Connected"' >/dev/null 2>&1; then
        log "INFO" "SSH connection successful"
    else
        log "WARN" "SSH connection failed, collection may fail"
    fi
}

# Get destination directory based on filename
get_destination_dir() {
    local filename=$1
    local date_string
    
    if [[ $filename =~ [0-9]{10} ]]; then
        local unix_time=${BASH_REMATCH[0]}
        date_string=$(date -d @"$unix_time" +"%Y/%m/%d")
    elif [[ $filename =~ 20[0-9]{6} ]]; then
        local date_part=${BASH_REMATCH[0]}
        local year=${date_part:0:4}
        local month=${date_part:4:2}
        local day=${date_part:6:2}
        date_string="$year/$month/$day"
    else
        log "WARN" "Unable to extract date from filename: $filename, using default"
        date_string=$(date +"%Y/%m/%d")
    fi
    
    echo "$DEST_PATH/$date_string"
}

# Collect files
collect_files() {
    log "INFO" "Starting collection from $SSH_USER@$WORKER_NODE"
    
    mkdir -p "$DEST_PATH"
    
    # Get list of files to collect (excluding most recent ones)
    local exclude_files
    exclude_files=$(ssh "$SSH_USER@$WORKER_NODE" "ls -t $SOURCE_PATH/*.pcap 2>/dev/null | head -n2" 2>/dev/null || echo "")
    
    # Get all files
    local all_files
    all_files=$(ssh "$SSH_USER@$WORKER_NODE" "ls -1 $SOURCE_PATH/*.pcap $SOURCE_PATH/*.pcap.gz 2>/dev/null" || echo "")
    
    if [[ -z "$all_files" ]]; then
        log "INFO" "No PCAP files to collect"
        return 0
    fi
    
    local files_to_copy=""
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            local basename_file=$(basename "$file")
            local should_exclude=false
            
            if [[ "$basename_file" == *.pcap ]]; then
                while IFS= read -r exclude_file; do
                    if [[ -n "$exclude_file" && "$(basename "$exclude_file")" == "$basename_file" ]]; then
                        should_exclude=true
                        break
                    fi
                done <<< "$exclude_files"
            fi
            
            if [[ "$should_exclude" == "false" ]]; then
                files_to_copy="$files_to_copy $file"
            fi
        fi
    done <<< "$all_files"
    
    if [[ -z "$files_to_copy" ]]; then
        log "INFO" "No files to collect (all are excluded as active)"
        return 0
    fi
    
    log "INFO" "Processing files from source"
    
    local copied_count=0
    for file in $files_to_copy; do
        local basename_file=$(basename "$file")
        local temp_file="$DEST_PATH/temp_$basename_file"
        
        set +e
        local rsync_output
        rsync_output=$(rsync -azP --timeout=300 "$SSH_USER@$WORKER_NODE:$file" "$temp_file" 2>&1)
        local exit_code=$?
        set -e
        
        if [[ $exit_code -eq 0 ]]; then
            local destination_dir
            destination_dir=$(get_destination_dir "$basename_file")
            
            mkdir -p "$destination_dir"
            
            if [[ "$basename_file" == *.pcap ]]; then
                log "INFO" "Compressing $basename_file"
                gzip "$temp_file"
                temp_file="${temp_file}.gz"
                basename_file="${basename_file}.gz"
            fi
            
            if mv "$temp_file" "$destination_dir/$basename_file"; then
                log "INFO" "Organized $basename_file to $destination_dir"
                
                if ssh "$SSH_USER@$WORKER_NODE" "rm '$file'" 2>/dev/null; then
                    log "INFO" "Deleted from source: $(basename "$file")"
                    copied_count=$((copied_count + 1))
                else
                    log "WARN" "Organized but failed to delete from source: $(basename "$file")"
                fi
            else
                log "ERROR" "Failed to organize $basename_file"
                rm -f "$temp_file" 2>/dev/null
            fi
        else
            log "ERROR" "Failed to copy: $basename_file"
        fi
    done
    
    if [[ $copied_count -gt 0 ]]; then
        log "INFO" "Successfully processed $copied_count files"
    else
        log "INFO" "No files were processed this cycle"
    fi
    
    return 0
}

# Signal handler for daemon mode
shutdown() {
    log "INFO" "Shutting down"
    ssh -O exit "$SSH_USER@$WORKER_NODE" 2>/dev/null || true
    exit 0
}

# Daemon mode (for docker-compose)
daemon_mode() {
    trap 'shutdown' SIGTERM SIGINT
    
    log "INFO" "Starting Darknet PCAP Collector (Daemon mode)"
    log "INFO" "Target: $SSH_USER@$WORKER_NODE"
    log "INFO" "Source: $SOURCE_PATH -> Destination: $DEST_PATH"
    log "INFO" "Collection interval: ${COLLECTION_INTERVAL}s"
    
    validate_env
    setup_ssh
    test_ssh
    
    local cycle=0
    while true; do
        cycle=$((cycle + 1))
        log "INFO" "Collection cycle $cycle"
        
        collect_files
        
        log "INFO" "Cycle $cycle completed"
        log "INFO" "Sleeping for ${COLLECTION_INTERVAL}s"
        sleep "$COLLECTION_INTERVAL"
    done
}

# CronJob mode (for kubernetes)
cronjob_mode() {
    log "INFO" "Starting Darknet PCAP Collector (CronJob mode)"
    log "INFO" "Target: $SSH_USER@$WORKER_NODE"
    log "INFO" "Source: $SOURCE_PATH -> Destination: $DEST_PATH"
    
    validate_env
    setup_ssh
    collect_files
    
    log "INFO" "Collection completed"
}

# Handle arguments and modes
case "${1:-}" in
    "test")
        validate_env
        setup_ssh
        collect_files
        ;;
    "health")
        echo "healthy"
        ;;
    "cronjob")
        cronjob_mode
        ;;
    *)
        if [[ "$RUN_MODE" == "cronjob" ]]; then
            cronjob_mode
        else
            daemon_mode
        fi
        ;;
esac