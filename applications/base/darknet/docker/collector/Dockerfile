FROM alpine:latest

# Install required packages
RUN apk add --no-cache \
    bash \
    openssh-client \
    rsync \
    curl \
    ca-certificates \
    gettext

# Create directories and setup SSH
RUN mkdir -p /app /data /root/.ssh \
    && chmod 700 /root/.ssh

# Create a non-root user for better security
RUN adduser -D -s /bin/bash collector \
    && mkdir -p /home/collector/.ssh \
    && chown -R collector:collector /home/collector

# Copy the collector script
COPY collector.sh /app/
RUN chmod +x /app/collector.sh

# Copy entrypoint script
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# Set working directory
WORKDIR /app

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pgrep -f collector.sh || exit 1

# Run as collector user (can be overridden in K8s)
USER collector

# Use entrypoint for setup + main script
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/collector.sh"]