#!/bin/bash
#
# PCAP Collector Script
# Collects pcap files from remote nodes and organizes them by date
#

# Print usage if requested
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage: $0"
  echo "Environment variables:"
  echo "  WORKER_NODES       : Space-separated list of worker nodes (required)"
  echo "  SSH_USERS          : Space-separated list of SSH usernames corresponding to worker nodes (required)"
  echo "  SOURCE_PATH        : Path to pcap files on remote nodes (required)"
  echo "  DEST_PATH          : Path to store collected pcaps (default: /data/collector)"
  echo "  COLLECTION_INTERVAL: Time between collection cycles in seconds (default: 3600)"
  echo "  SSH_OPTS           : Additional SSH options (optional)"
  exit 0
fi

# Validate required environment variables
if [ -z "$WORKER_NODES" ]; then
  echo "ERROR: WORKER_NODES environment variable must be set"
  exit 1
fi

if [ -z "$SOURCE_PATH" ]; then
  echo "ERROR: SOURCE_PATH environment variable must be set"
  exit 1
fi

if [ -z "$SSH_USERS" ]; then
  echo "ERROR: SSH_USERS environment variable must be set"
  exit 1
fi

# Set default values for optional variables
DEST_PATH=${DEST_PATH:-"/data/collector"}
COLLECTION_INTERVAL=${COLLECTION_INTERVAL:-3600}
SSH_OPTS=${SSH_OPTS:-"-o StrictHostKeyChecking=no"}

# Ensure SSH key exists
if [ ! -f /etc/ssh-keys/id_rsa ]; then
  echo "ERROR: SSH key not found at /etc/ssh-keys/id_rsa"
  exit 1
fi

# Setup SSH configuration
cp /etc/ssh-keys/id_rsa /root/.ssh/
chmod 600 /root/.ssh/id_rsa

# Convert space-separated lists to arrays
read -ra WORKER_NODES_ARRAY <<< "$WORKER_NODES"
read -ra SSH_USERS_ARRAY <<< "$SSH_USERS"

# Validate that we have the same number of nodes and users
if [ ${#WORKER_NODES_ARRAY[@]} -ne ${#SSH_USERS_ARRAY[@]} ]; then
  echo "ERROR: Number of worker nodes (${#WORKER_NODES_ARRAY[@]}) does not match number of SSH users (${#SSH_USERS_ARRAY[@]})"
  echo "WORKER_NODES: $WORKER_NODES"
  echo "SSH_USERS: $SSH_USERS"
  exit 1
fi

# Add known hosts to avoid prompts
for NODE in ${WORKER_NODES_ARRAY[@]}; do
  ssh-keyscan -H $NODE >> /root/.ssh/known_hosts 2>/dev/null
done

echo "PCAP Collector started"
echo "Worker nodes: $WORKER_NODES"
echo "SSH users: $SSH_USERS"
echo "Source path: $SOURCE_PATH"
echo "Destination path: $DEST_PATH"
echo "Collection interval: $COLLECTION_INTERVAL seconds"

# Run collection job on a schedule
while true; do
  CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$CURRENT_TIME] Starting collection cycle"
  
  for i in "${!WORKER_NODES_ARRAY[@]}"; do
    NODE=${WORKER_NODES_ARRAY[$i]}
    SSH_USER=${SSH_USERS_ARRAY[$i]}
    
    echo "Processing node: $NODE with user: $SSH_USER"
    
    # Create target directory structure
    NODE_DEST_PATH="${DEST_PATH}/${NODE}"
    mkdir -p "$NODE_DEST_PATH"
    
    # Get node IP - either from hostname or DNS lookup
    if getent hosts $NODE &>/dev/null; then
      NODE_IP=$(getent hosts $NODE | awk '{ print $1 }')
    else
      # Fallback to the node name as IP if DNS lookup fails
      NODE_IP=$NODE
    fi
    
    echo "Using IP: $NODE_IP for node $NODE"
    
    # Run rsync, excluding the most recent file to avoid capturing incomplete files
    EXCLUDE_FILE=$(ssh $SSH_OPTS -i /root/.ssh/id_rsa ${SSH_USER}@${NODE_IP} "ls -t ${SOURCE_PATH}/ 2>/dev/null | grep -E '\.pcap$' | head -n1" || echo "")
    
    if [ -n "$EXCLUDE_FILE" ]; then
      echo "Excluding most recent file: $EXCLUDE_FILE"
      EXCLUDE_OPTION="--exclude=$EXCLUDE_FILE"
    else
      echo "No files found to exclude"
      EXCLUDE_OPTION=""
    fi
    
    # Run rsync with proper error handling
    echo "Running rsync from ${SSH_USER}@${NODE_IP}:${SOURCE_PATH}/ to $NODE_DEST_PATH/"
    
    rsync -azP --mkpath $EXCLUDE_OPTION \
      -e "ssh $SSH_OPTS -i /root/.ssh/id_rsa" \
      ${SSH_USER}@${NODE_IP}:${SOURCE_PATH}/*.pcap $NODE_DEST_PATH/ || {
        echo "Warning: rsync from ${NODE_IP} failed with exit code $?"
        continue
      }
    
    # Organize files by date
    echo "Organizing files by date structure"
    cd $NODE_DEST_PATH
    
    # Use find to avoid shell globbing issues
    find . -maxdepth 1 -name "*.pcap" | while read -r filepath; do
      filename=$(basename "$filepath")
      
      # Skip if not a valid file
      if [ ! -f "$filepath" ]; then
        continue
      fi
      
      # Extract date parts from filename (trace-YYYYMMDD_HH-MM-SS_SOMENUMBER.pcap)
      if [[ $filename =~ trace-([0-9]{8})_([0-9]{2})-([0-9]{2})-([0-9]{2})_([0-9]+)\.pcap ]]; then
        date_part=${BASH_REMATCH[1]}
        
        # Extract year, month, and day
        year=${date_part:0:4}
        month=${date_part:4:2}
        day=${date_part:6:2}
        
        # Create directory structure
        mkdir -p "$year/$month/$day"
        
        # Move the file
        mv "$filepath" "$year/$month/$day/"
        echo "Moved $filename to $year/$month/$day/"
      else
        echo "Warning: Filename $filename doesn't match expected pattern, skipping organization"
      fi
    done
    
    echo "Completed processing for node: $NODE"
  done
  
  CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$CURRENT_TIME] Collection cycle complete. Sleeping for ${COLLECTION_INTERVAL} seconds"
  sleep ${COLLECTION_INTERVAL}
done