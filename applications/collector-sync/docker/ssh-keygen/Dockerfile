FROM alpine:latest

# Install required packages during build (when network is available)
RUN apk add --no-cache \
    openssh-keygen \
    curl \
    bash

# Download kubectl during build
RUN curl -LO "https://dl.k8s.io/release/v1.35.2/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl

# Copy the key generation script
COPY generate-keys.sh /generate-keys.sh
RUN chmod +x /generate-keys.sh

CMD ["/generate-keys.sh"]