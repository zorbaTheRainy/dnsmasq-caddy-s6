# Define the build argument (can be basic alpine for just dnsmasq/webproc,  or also caddy-alpine; tailscale can be added as S6 docker mod)
    # Alpine docker image  ->  https://hub.docker.com/_/alpine
    # Caddy docker image   ->  https://hub.docker.com/_/caddy
    # S6 Overlay           ->  https://github.com/just-containers/s6-overlay
    # Tailscale Docker Mod ->  https://github.com/tailscale-dev/docker-mod
ARG BASE_IMAGE=alpine:latest
# FROM ${BASE_IMAGE}
FROM ghcr.io/linuxserver/baseimage-alpine:3.20

# inherent in the build system
ARG TARGETARCH
ARG TARGETVARIANT

# passed via GitHub Action
ARG BUILD_TIME
ARG IS_S6=false
ARG WEBPROC_VERSION=0.4.0
ARG BASE_IMAGE_TMP

# Set up URLs, which are dynamically created based on the version desired
ENV WEBPROC_URL_AMD64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_amd64.gz
ENV WEBPROC_URL_ARM64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_arm64.gz
ENV WEBPROC_URL_ARMv7 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv7.gz
ENV WEBPROC_URL_ARMv6 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv6.gz

# Add labels to the image metadata
LABEL BASE_IMAGE=${BASE_IMAGE_TMP}
LABEL WEBPROC_VERSION=${WEBPROC_VERSION}
LABEL release-date=${BUILD_TIME}
LABEL source="https://github.com/zorbaTheRainy/docker-dnsmasq"
LABEL maintainer="ZorbaTheRainy"


# copy over files that run scripts  NOTE:  do NOT forget to chmod 755 them in the git folder (or they won't be executable in the image)
COPY keep_alive.sh /etc/keep_alive.sh
COPY start.sh /etc/start.sh
COPY dnsmasq_run.sh /etc/dnsmasq_run.sh

# webproc release settings
COPY dnsmasq.conf /etc/dnsmasq.conf
# fetch dnsmasq and webproc binary
RUN apk update && \
	apk --no-cache add dnsmasq && \
	apk add --no-cache --virtual .build-deps curl && \
	case "${TARGETARCH}" in \
		amd64)  curl -sL $WEBPROC_URL_AMD64 | gzip -d - > /usr/local/bin/webproc   ;; \
		arm64)  curl -sL $WEBPROC_URL_ARM64 | gzip -d - > /usr/local/bin/webproc   ;; \
        arm) \
            case "${TARGETVARIANT}" in \
                v6)   curl -sL $WEBPROC_URL_ARMv6 | gzip -d - > /usr/local/bin/webproc   ;; \
                v7)   curl -sL $WEBPROC_URL_ARMv7 | gzip -d - > /usr/local/bin/webproc   ;; \
                v8)   curl -sL $WEBPROC_URL_ARM64 | gzip -d - > /usr/local/bin/webproc   ;; \
                *) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
            esac;  ;; \
		*) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
    esac  && \
	chmod +x /usr/local/bin/webproc && \
	apk del .build-deps && \
    mkdir -p /etc/default/ && \
    echo -e "ENABLED=1\nIGNORE_RESOLVCONF=yes" > /etc/default/dnsmasq &&\
    mkdir -p /etc/services.d/dnsmasq && \
    cp /etc/dnsmasq_run.sh /etc/services.d/dnsmasq/run



EXPOSE 53/udp 8080

# Run the desired programs
  # runs dnsmasq/webproc and caddy (if it is installed)
