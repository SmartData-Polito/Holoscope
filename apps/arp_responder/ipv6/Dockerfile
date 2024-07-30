FROM gcc:bookworm
COPY ./thc-ipv6 /usr/src/arpv6
WORKDIR /usr/src/arpv6

# Install Dependencies
RUN apt-get update -qq
RUN apt-get -y install \
    libdumbnet-dev  \
    libdumbnet1 \
    libbsd-dev \
    libpcap-dev \
    libssl-dev

RUN make all
RUN make install

