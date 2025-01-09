FROM debian:stable-slim

# Build arguments
ARG S6_OVERLAY_VERSION=3.2.0.2
ARG TARGETARCH

# ENV variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ="America/New_York"
ENV CUPSADMIN=admin
ENV CUPSPASSWORD=password


LABEL org.opencontainers.image.source="https://github.com/manuelm/cups-docker"
LABEL org.opencontainers.image.description="CUPS Printer Server"
LABEL org.opencontainers.image.author="Manuel M"
LABEL org.opencontainers.image.url="https://github.com/manuelm/cups-docker/blob/main/README.md"
LABEL org.opencontainers.image.licenses=MIT

# Install dependencies
RUN --mount=type=bind,source=services,target=/tmp/s6/services \
    --mount=type=bind,source=cont-init,target=/tmp/s6/cont-init <<-"EOF" bash
    set -ex
    apt-get update -qq
    apt-get upgrade -qqy
    apt-get install --no-install-recommends --no-install-suggests -qqy \
        cups cups-filters \
        foomatic-db-compressed-ppds \
        avahi-daemon \
        wget ca-certificates
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    
    # Baked-in config file changes
    sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
    sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/>/<Location \/>\n  Allow All/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow All\n  Require user @SYSTEM/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin\/conf>/<Location \/admin\/conf>\n  Allow All/' /etc/cups/cupsd.conf && \
    echo "ServerAlias *" >> /etc/cups/cupsd.conf && \
    echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf
    
    # install S6
    S6_OVERLAY_ARCH=x86_64
    if [[ "${TARGETARCH}" == "amd64" ]]; then
        S6_OVERLAY_ARCH="x86_64"
    elif [[ "${TARGETARCH}" == "arm64" ]]; then
        S6_OVERLAY_ARCH="aarch64"
    elif [[ "${TARGETARCH}" == "arm/v6" ]]; then
        S6_OVERLAY_ARCH="armhf"
    elif [[ "${TARGETARCH}" == "arm/v7" || "${TARGETARCH}" == "arm" ]]; then
        S6_OVERLAY_ARCH="arm"
    fi
    
    echo "Building with TARGETARCH=${TARGETARCH} and S6_OVERLAY_ARCH=${S6_OVERLAY_ARCH}"
    wget -qO- "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" | tar -C / -Jxpf -
    wget -qO- "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" | tar -C / -Jxpf -
    wget -qO- "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz" | tar -C / -Jxpf -
    wget -qO- "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz" | tar -C / -Jxpf -
    
    # Add s6 service definitions
    cp -r /tmp/s6/services /etc/services.d
    cp -r /tmp/s6/cont-init /etc/cont-init.d
EOF

EXPOSE 631
EXPOSE 5353/udp

VOLUME [ "/etc/cups" ]

# Command to start s6-init
CMD ["/init"]
