#!/bin/bash
set -euo pipefail

echo "Starting SSH key generation..."

# Configuration
KEY_PATH="${KEY_PATH:-/tmp/ssh-keys}"
KEY_NAME="${KEY_NAME:-id_rsa}"
KEY_TYPE="${KEY_TYPE:-rsa}"
KEY_BITS="${KEY_BITS:-2048}"
KEY_COMMENT="${KEY_COMMENT:-darknet-collector}"

# For Kubernetes mode
K8S_MODE="${K8S_MODE:-false}"
SECRET_NAME="${SECRET_NAME:-collector-ssh-key}"

# Create key directory
mkdir -p "$KEY_PATH"

# Generate SSH key pair (remove existing keys first)
echo "Generating SSH key pair..."
rm -f "$KEY_PATH/$KEY_NAME" "$KEY_PATH/$KEY_NAME.pub"
ssh-keygen -t "$KEY_TYPE" -b "$KEY_BITS" -f "$KEY_PATH/$KEY_NAME" -N '' -C "$KEY_COMMENT" -q

# Set proper permissions
chmod 600 "$KEY_PATH/$KEY_NAME"
chmod 644 "$KEY_PATH/$KEY_NAME.pub"

echo "SSH key pair generated successfully:"
echo "  Private key: $KEY_PATH/$KEY_NAME"
echo "  Public key:  $KEY_PATH/$KEY_NAME.pub"
echo "  Fingerprint: $(ssh-keygen -l -f "$KEY_PATH/$KEY_NAME.pub")"

# If in Kubernetes mode, create secret via kubectl
if [[ "$K8S_MODE" == "true" ]]; then
    echo "Creating Kubernetes secret using kubectl..."
    
    # Create secret using kubectl (much simpler than API calls)
    kubectl create secret generic "$SECRET_NAME" \
        --from-file=id_rsa="$KEY_PATH/$KEY_NAME" \
        --from-file=id_rsa.pub="$KEY_PATH/$KEY_NAME.pub" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    if [[ $? -eq 0 ]]; then
        echo "Kubernetes secret '$SECRET_NAME' created successfully"
    else
        echo "Failed to create Kubernetes secret"
        exit 1
    fi
else
    echo "File-based mode: Keys saved to $KEY_PATH"
    echo "Public key content:"
    cat "$KEY_PATH/$KEY_NAME.pub"
fi

echo "SSH key generation completed successfully"