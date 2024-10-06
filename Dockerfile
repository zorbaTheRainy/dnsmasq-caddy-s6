# Define the build argument (can be basic alpine for just dnsmasq/webproc,  or also caddy-alpine; tailscale can be added as S6 docker mod)
    # Alpine docker image  ->  https://hub.docker.com/_/alpine
    # Caddy docker image   ->  https://hub.docker.com/_/caddy
    # S6 Overlay           ->  https://github.com/just-containers/s6-overlay
    # Tailscale Docker Mod ->  https://github.com/tailscale-dev/docker-mod
ARG BASE_IMAGE=alpine:latest
# FROM ${BASE_IMAGE}
FROM alpine:latest

# inherent in the build system
ARG TARGETARCH
ARG TARGETVARIANT

# passed via GitHub Action
ARG BUILD_TIME
ARG WEBPROC_VERSION=0.4.0
ARG S6_OVERLAY_VERSION=3.2.0.0
ARG BASE_IMAGE_TMP

# Add labels to the image metadata
LABEL BASE_IMAGE=${BASE_IMAGE_TMP}
LABEL WEBPROC_VERSION=${WEBPROC_VERSION}
LABEL S6_OVERLAY_VERSION=${S6_OVERLAY_VERSION}
LABEL release-date=${BUILD_TIME}
LABEL source="https://github.com/zorbaTheRainy/docker-dnsmasq"
LABEL maintainer="dev@jpillora.com, and forked by ZorbaTheRainy"

# -------------------------------------------------------------------------------------------------
# Services
# -------------------------------------------------------------------------------------------------


# S6 Overlay           ->  https://github.com/just-containers/s6-overlay
# -------------------------------------------------------------------------------------------------

# Pull all the files (avoids `curl`, but causes use to pull more than we need, all archs not just one)
#ENV S6_URL_ROOT       https://github.com/just-containers/s6-overlay/releases/download/v{S6_OVERLAY_VERSION}
ENV S6_URL_ROOT       https://github.com/just-containers/s6-overlay/releases/download/v3.2.0.0
# no-arch files
ADD ${S6_URL_ROOT}/s6-overlay-noarch.tar.xz            /tmp/s6-overlay-noarch.tar.xz
ADD ${S6_URL_ROOT}/s6-overlay-symlinks-noarch.tar.xz   /tmp/s6-overlay-symlinks-noarch.tar.xz
ADD ${S6_URL_ROOT}/s6-overlay-symlinks-arch.tar.xz     /tmp/s6-overlay-symlinks-yesarch.tar.xz
# Add architecture-specific files (note the difference in naming convenrtion between S6 & Docker)
ADD ${S6_URL_ROOT}/s6-overlay-x86_64.tar.xz            /tmp/s6-overlay-yesarch-amd64.tar.xz
ADD ${S6_URL_ROOT}/s6-overlay-aarch64.tar.xz           /tmp/s6-overlay-yesarch-arm64.tar.xz
ADD ${S6_URL_ROOT}/s6-overlay-arm.tar.xz               /tmp/s6-overlay-yesarch-armv7.tar.xz
ADD ${S6_URL_ROOT}/s6-overlay-armhf.tar.xz             /tmp/s6-overlay-yesarch-armv6.tar.xz

# integrate the files into the file system
RUN apk update && \
    apk add --no-cache bash xz && \
    case "${TARGETARCH}" in \
        amd64)  mv /tmp/s6-overlay-yesarch-amd64.tar.xz /tmp/s6-overlay-yesarch.tar.xz  ;; \
        arm64)  mv /tmp/s6-overlay-yesarch-arm64.tar.xz /tmp/s6-overlay-yesarch.tar.xz  ;; \
        arm) \
            case "${TARGETVARIANT}" in \
                v6)   mv /tmp/s6-overlay-yesarch-armv6.tar.xz /tmp/s6-overlay-yesarch.tar.xz  ;; \
                v7)   mv /tmp/s6-overlay-yesarch-armv7.tar.xz /tmp/s6-overlay-yesarch.tar.xz  ;; \
                v8)   mv /tmp/s6-overlay-yesarch-arm64.tar.xz /tmp/s6-overlay-yesarch.tar.xz  ;; \
                *) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
            esac ;; \
        *) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
    esac && \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-yesarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-symlinks-yesarch.tar.xz && \
    rm -rf /tmp/s6-overlay-*.tar.xz && \
    touch /s6_installed.txt \
    ; 

# S6 Overlay           ->  https://github.com/just-containers/s6-overlay
# -------------------------------------------------------------------------------------------------

    # Set up URLs, which are dynamically created based on the version desired
ENV WEBPROC_URL_AMD64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_amd64.gz
ENV WEBPROC_URL_ARM64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_arm64.gz
ENV WEBPROC_URL_ARMv7 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv7.gz
ENV WEBPROC_URL_ARMv6 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv6.gz



EXPOSE 53/udp 8080

# Run the desired programs
    # runs dnsmasq/webproc and caddy (if it is installed)
# CMD ["/etc/start.sh"]
# ENTRYPOINT ["/init"]
