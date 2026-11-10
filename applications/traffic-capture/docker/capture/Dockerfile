FROM nicolaka/netshoot:latest

# Install
RUN apk add --no-cache \
    wireshark-common \
    shadow \
    su-exec \
    libcap

# Create capture user with proper settings
RUN addgroup -g 2000 capture && \
    adduser -D -u 2000 -G capture \
      -s /bin/bash -h /home/capture capture && \
    echo "capture:*" | chpasswd -e

# Create wireshark group and add capture user to it
RUN  adduser capture wireshark
RUN  adduser capture wheel
RUN  adduser capture root
RUN chmod 750 /usr/bin/dumpcap && \
    chgrp wireshark /usr/bin/dumpcap && \
    setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap


# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create data directory with proper permissions
RUN mkdir -p /data/darknet && \
    chown capture:capture /data/darknet

# Run as root initially (entrypoint will switch users as needed)
USER root

CMD ["/entrypoint.sh"]