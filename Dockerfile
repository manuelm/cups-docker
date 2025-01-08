FROM debian:stable-slim

# Build arguments
ARG S6_OVERLAY_VERSION=3.2.0.2
ARG TARGETARCH

# ENV variables
ENV DEBIAN_FRONTEND noninteractive
ENV TZ "America/New_York"
ENV CUPSADMIN admin
ENV CUPSPASSWORD password


LABEL org.opencontainers.image.source="https://github.com/manuelm/cups-docker"
LABEL org.opencontainers.image.description="CUPS Printer Server"
LABEL org.opencontainers.image.author="Manuel M"
LABEL org.opencontainers.image.url="https://github.com/manuelm/cups-docker/blob/main/README.md"
LABEL org.opencontainers.image.licenses=MIT

# Add script for installing s6-overlay
COPY ./scripts /tmp/scripts

# Install dependencies
RUN apt-get update -qq && apt-get upgrade -qqy \
    && apt-get install --no-install-recommends --no-install-suggests -qqy \
        cups \
        cups-filters \
        foomatic-db-compressed-ppds \
        avahi-daemon \
    && /tmp/scripts/install-s6-overlay.sh \
    && rm -rf /tmp/scripts \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 631
EXPOSE 5353/udp

# Baked-in config file changes
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
    sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/>/<Location \/>\n  Allow All/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow All\n  Require user @SYSTEM/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin\/conf>/<Location \/admin\/conf>\n  Allow All/' /etc/cups/cupsd.conf && \
    echo "ServerAlias *" >> /etc/cups/cupsd.conf && \
    echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf

# back up cups configs in case used does not add their own
RUN cp -rp /etc/cups /etc/cups-bak
VOLUME [ "/etc/cups" ]

# Add s6 service definitions
COPY ./services /etc/services.d
COPY ./cont-init /etc/cont-init.d

# Command to start s6-init
CMD ["/init"]
