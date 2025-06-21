FROM alpine:latest

# Install required packages
RUN apk add --no-cache \
    bash \
    openssh-client \
    rsync \
    findutils \
    coreutils \
    gzip

# Copy collector script
COPY collector.sh /collector.sh
RUN chmod +x /collector.sh

# Create data directory
RUN mkdir -p /data/collector

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD /collector.sh health

USER root

CMD ["/collector.sh"]