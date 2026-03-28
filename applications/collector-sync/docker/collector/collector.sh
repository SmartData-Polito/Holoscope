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
        DEBUG) 
            if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
                echo "[$timestamp] [DEBUG] $*"
            fi
            ;;
        INFO)  echo "[$timestamp] [INFO] $*" ;;
        WARN)  echo "[$timestamp] [WARN] $*" ;;
        ERROR) echo "[$timestamp] [ERROR] $*" >&2 ;;
    esac
}

parse_worker_node() {
    log "INFO" "Parsing WORKER_NODE: $WORKER_NODE"
    if [[ "$WORKER_NODE" == *:* ]]; then
        SSH_HOST="${WORKER_NODE%:*}"
        SSH_PORT="${WORKER_NODE#*:}"
    else
        SSH_HOST="$WORKER_NODE"
        SSH_PORT="65222"
    fi
    
    log "INFO" "Parsed connection: host=$SSH_HOST, port=$SSH_PORT"
}


validate_env() {
    log "INFO" "Validating environment variables"
    if [[ -z "$WORKER_NODE" ]] || [[ -z "$SSH_USER" ]]; then
        log "ERROR" "WORKER_NODE and SSH_USER environment variables are required"
        exit 1
    fi
    parse_worker_node
    
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
    
    # Parse hostname and port from WORKER_NODE
    local ssh_host
    local ssh_port=65222
    
    if [[ "$WORKER_NODE" == *:* ]]; then
        ssh_host="${WORKER_NODE%:*}"
        ssh_port="${WORKER_NODE#*:}"
    else
        ssh_host="$WORKER_NODE"
    fi
    
    cat > /root/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ConnectTimeout 15
    IdentityFile /root/.ssh/id_rsa
    BatchMode yes
    PasswordAuthentication no
    PubkeyAuthentication yes

Host $ssh_host
    Port $ssh_port
EOF
    chmod 600 /root/.ssh/config
}

# Test SSH connection
test_ssh() {
    log "INFO" "Testing SSH connection to $SSH_USER@$SSH_HOST:$SSH_PORT"
    if ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" 'echo "Connected"' >/dev/null 2>&1; then
        log "INFO" "SSH connection successful"
    else
        log "WARN" "SSH connection failed, collection may fail"
    fi
}

# Get destination directory based on filename
get_destination_dir() {
    local filename=$1
    local date_string
    
    if [[ $filename =~ _[0-9]+_([0-9]{4})([0-9]{2})([0-9]{2})[0-9]{6}\.pcap ]]; then
        local year=${BASH_REMATCH[1]}
        local month=${BASH_REMATCH[2]}
        local day=${BASH_REMATCH[3]}
        date_string="$year/$month/$day"
        #log "INFO" "Full date: $date_string"
    
    elif [[ $filename =~ [0-9]{10} ]]; then
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
    #log "INFO" "Destination directory for $filename: $DEST_PATH/$date_string"
    echo "$DEST_PATH/$date_string"
}

# Collect files
collect_files() {
    log "INFO" "Starting collection from $SSH_USER@$WORKER_NODE"
    
    mkdir -p "$DEST_PATH"
    
    # Get list of files to collect (excluding most recent ones)
    local exclude_files
    exclude_files=$(ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "ls -t $SOURCE_PATH/*.pcap 2>/dev/null | head -n2" 2>/dev/null || echo "")
    
    # Get all files
    local all_files
    all_files=$(ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "ls -1 $SOURCE_PATH/*.pcap $SOURCE_PATH/*.pcap.gz 2>/dev/null" || echo "")
      
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
        
        # Add debugging information
        log "DEBUG" "Attempting to copy: $SSH_USER@$SSH_HOST:$file -> $temp_file"
        log "DEBUG" "SSH command: ssh -p $SSH_PORT"
        
        set +e
        local rsync_output
        rsync_output=$(rsync -azP --no-perms --timeout=300 -e "ssh -p $SSH_PORT" "$SSH_USER@$SSH_HOST:$file" "$temp_file" 2>&1)

        local exit_code=$?
        set -e
        
        if [[ $exit_code -eq 0 ]]; then
            local destination_dir
            log "DEBUG" "file name: $basename_file"
            
            destination_dir=$(get_destination_dir "$basename_file")
            log "DEBUG" "destination $destination_dir"
            mkdir -p "$destination_dir"
            
            if [[ "$basename_file" == *.pcap ]]; then
                log "INFO" "Compressing $basename_file (size: $(du -h "$temp_file" | cut -f1))"
                
                # Check available disk space before compression
                local available_space
                available_space=$(df "$DEST_PATH" | awk 'NR==2 {print $4}')
                log "DEBUG" "Available disk space: ${available_space}KB"
                
                if ! gzip "$temp_file"; then
                    log "ERROR" "Failed to compress $basename_file"
                    rm -f "$temp_file" 2>/dev/null
                    continue
                fi
                
                temp_file="${temp_file}.gz"
                basename_file="${basename_file}.gz"
                log "INFO" "Compression completed (new size: $(du -h "$temp_file" | cut -f1))"
            fi
            
            if mv "$temp_file" "$destination_dir/$basename_file"; then
                log "INFO" "Organized $basename_file to $destination_dir"
                if ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "rm '$file'" 2>/dev/null; then
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
            log "ERROR" "Failed to copy: $basename_file (exit code: $exit_code)"
            log "ERROR" "Rsync output: $rsync_output"
            
            # Additional debugging - test SSH connectivity
            log "DEBUG" "Testing SSH connectivity..."
            if ssh -p "$SSH_PORT" -o ConnectTimeout=10 "$SSH_USER@$SSH_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
                log "DEBUG" "SSH connection is working"
                # Test if the file actually exists
                if ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "test -f '$file'" 2>/dev/null; then
                    log "DEBUG" "File exists on remote server: $file"
                    # Check file permissions
                    ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "ls -la '$file'" 2>/dev/null || log "DEBUG" "Could not get file permissions"
                else
                    log "DEBUG" "File does not exist on remote server: $file"
                fi
            else
                log "ERROR" "SSH connection failed to $SSH_USER@$SSH_HOST:$SSH_PORT"
            fi
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
    log "WARN" "Received shutdown signal during operation"
    
    # Clean up any temporary files
    rm -f "$DEST_PATH"/temp_* 2>/dev/null || true
    
    # Close SSH connections
    ssh -O exit "$SSH_USER@$WORKER_NODE" 2>/dev/null || true
    
    log "INFO" "Shutdown complete"
    exit 0
}

# Daemon mode (for docker-compose)
daemon_mode() {
    trap 'shutdown' SIGTERM SIGINT
    
    log "INFO" "Starting PCAP Collector (Daemon mode)"
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
    log "INFO" "Starting PCAP Collector (CronJob mode)"
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