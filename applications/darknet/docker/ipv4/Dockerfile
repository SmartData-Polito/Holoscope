FROM gcc:bookworm
COPY . /usr/src/arpd
WORKDIR /usr/src/arpd

# Install Dependencies
RUN apt-get update -qq
RUN apt-get -y install \
    libdumbnet-dev  \
    libdumbnet1 \
    libbsd-dev \
    libpcap-dev 

RUN gcc /usr/src/arpd/arpd.c -o /usr/src/arpd/farpd2 -ldumbnet -levent -lpcap -lbsd