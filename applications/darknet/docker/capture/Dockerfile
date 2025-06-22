FROM nicolaka/netshoot:latest

# Install SSH server and other required packages
RUN apk add --no-cache \
    openssh-server \
    openssh-keygen \
    rsync \
    shadow \
    su-exec

# Create capture user with proper settings
RUN adduser -D -s /bin/bash -h /home/capture capture && \
    echo "capture:*" | chpasswd -e

# Configure SSH directories with proper permissions
RUN mkdir -p /run/sshd && \
    mkdir -p /home/capture/.ssh && \
    chown -R capture:capture /home/capture && \
    chmod 700 /home/capture/.ssh && \
    chmod 755 /home/capture

# Copy SSH configuration
COPY sshd_config /etc/ssh/sshd_config

# Generate SSH host keys
RUN ssh-keygen -A && \
    chmod 600 /etc/ssh/ssh_host_*_key && \
    chmod 644 /etc/ssh/ssh_host_*_key.pub

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create data directory with proper permissions
RUN mkdir -p /data/darknet && \
    chown capture:capture /data/darknet

# Expose SSH port
EXPOSE 65222

# Run as root initially (entrypoint will switch users as needed)
USER root

# Health check to verify SSH is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD netstat -tlnp | grep ":65222 " || exit 1

CMD ["/entrypoint.sh"]