FROM alpine:latest

# Install required packages
RUN apk add --no-cache \
    bash \
    openssh-client \
    rsync \
    curl \
    gettext

# Create directories
RUN mkdir -p /app /data /root/.ssh

# Copy the collector script
COPY collector.sh /app/
RUN chmod +x /app/collector.sh

# Set working directory
WORKDIR /app

# Default command
ENTRYPOINT ["/app/collector.sh"]