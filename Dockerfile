# Multi-stage Dockerfile for MangosZero Pterodactyl
# Stage 1: Builder
FROM debian:bullseye-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install Build Dependencies
RUN apt-get update && apt-get install -y \
    git cmake build-essential clang pkg-config \
    libace-dev libssl-dev libmariadb-dev libmariadb-dev-compat \
    libtool libbz2-dev libreadline-dev zlib1g-dev libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy entire repo content context
COPY . .

# Compile
RUN mkdir build && cd build && \
    export CC=clang && export CXX=clang++ && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/opt/mangos \
             -DBUILD_MANGOSD=1 \
             -DBUILD_REALMD=1 \
             -DBUILD_TOOLS=0 \
             -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_C_COMPILER=clang \
             -DCMAKE_CXX_COMPILER=clang++ && \
    make -j$(nproc) && \
    make install

# Copy SQL files to install location
RUN cp -r sql /opt/mangos/sql

# Stage 2: Runtime
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install Runtime Dependencies (Lighter than build deps)
RUN apt-get update && apt-get install -y \
    libace-6.5.12 libssl1.1 libmariadb3 \
    libreadline8 libncurses6 libbz2-1.0 zlib1g \
    curl ca-certificates tzdata iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Create user for Pterodactyl
RUN useradd -m -d /home/container -s /bin/bash container

USER container
ENV USER=container HOME=/home/container

WORKDIR /home/container

# Copy compiled binaries and files from builder
COPY --from=builder --chown=container:container /opt/mangos /opt/mangos

# Copy entrypoint
COPY --chown=container:container entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables
ENV LD_LIBRARY_PATH=/opt/mangos/lib

CMD ["/bin/bash", "/entrypoint.sh"]
