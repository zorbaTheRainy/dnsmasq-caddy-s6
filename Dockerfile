# Define the build argument (can be basic alpine for just dnsmasq/webproc,  or also caddy-alpine; tailscale can be added as S6 docker mod)
    # Alpine docker image    ->  https://hub.docker.com/_/alpine
    # S6 Overlay             ->  https://github.com/just-containers/s6-overlay
    # dnsmasq/webproc docker ->  https://github.com/jpillora/docker-dnsmasq
    # Caddy docker image     ->  https://hub.docker.com/_/caddy
    # Tailscale Docker Mod   ->  https://github.com/tailscale-dev/docker-mod

# -------------------------------------------------------------------------------------------------
# Stage 0: Create base image and set ENV/LABELS
# -------------------------------------------------------------------------------------------------
# FROM ${BASE_IMAGE}
ARG BASE_IMAGE=alpine:latest
# FROM ${BASE_IMAGE} as base
FROM alpine:latest as base

# passed via GitHub Action
ARG BUILD_TIME
ARG BASE_IMAGE_TMP

# passed via GitHub Action (but used in Stage 1: Build)
# ARG S6_OVERLAY_VERSION=3.2.0.0
# ARG WEBPROC_VERSION=0.4.0

# Add labels to the image metadata
LABEL BASE_IMAGE=${BASE_IMAGE_TMP}
LABEL release-date=${BUILD_TIME}
LABEL source="https://github.com/zorbaTheRainy/docker-dnsmasq"

# -------------------------------------------------------------------------------------------------
# Stage 1: Build image
# -------------------------------------------------------------------------------------------------
FROM base as rootfs-stage

# inherent in the build system
ARG TARGETARCH
ARG TARGETVARIANT

    # -------------------------------------------------------------------------------------------------
    # Services
    # -------------------------------------------------------------------------------------------------

    # -------------------------------------------------------------------------------------------------
    # S6 Overlay           ->  https://github.com/just-containers/s6-overlay
# -------------------------------------------------------------------------------------------------

# Inputs 
ARG S6_OVERLAY_VERSION=3.2.0.0
LABEL S6_OVERLAY_VERSION=${S6_OVERLAY_VERSION}

# Pull all the files (avoids `curl`, but causes use to pull more than we need, all archs not just one)
ENV S6_URL_ROOT       https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}
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

    # -------------------------------------------------------------------------------------------------
    # dnsmasq/webproc docker ->  https://github.com/jpillora/docker-dnsmasq
# -------------------------------------------------------------------------------------------------

# Inputs 
ARG INCLUDE_DNSMASQ_WEBPROC=true
ARG WEBPROC_VERSION=0.4.0
LABEL WEBPROC_VERSION=${WEBPROC_VERSION}


# Pull all the files (avoids `curl`, but causes use to pull more than we need, all archs not just one)
ENV WEBPROC_URL_ROOT  https://github.com/jpillora/webproc/releases/download/v${WEBPROC_VERSION}/webproc_${WEBPROC_VERSION}
ADD ${WEBPROC_URL_ROOT}_linux_amd64.gz      /tmp/webproc_amd64.gz
ADD ${WEBPROC_URL_ROOT}_linux_arm64.gz      /tmp/webproc_arm64.gz
ADD ${WEBPROC_URL_ROOT}_linux_armv7.gz      /tmp/webproc_armv7.gz
ADD ${WEBPROC_URL_ROOT}_linux_armv6.gz      /tmp/webproc_armv6.gz

# copy over files that run scripts  NOTE:  do NOT forget to chmod 755 them in the git folder (or they won't be executable in the image)
COPY dnsmasq.conf /etc/dnsmasq.conf
COPY dnsmasq_run.sh /tmp/dnsmasq_run.sh

# integrate the files into the file system
# fetch dnsmasq and webproc binary
RUN if [ "${INCLUDE_DNSMASQ_WEBPROC}" = "true" ]; then \
        apk update && \
        apk --no-cache add dnsmasq && \
        apk add --no-cache --virtual .build-deps curl && \
        case "${TARGETARCH}" in \
            amd64)  gzip -d /tmp/webproc_amd64.gz > /usr/local/bin/webproc   ;; \
            arm64)  gzip -d /tmp/webproc_arm64.gz > /usr/local/bin/webproc   ;; \
            arm) \
                case "${TARGETVARIANT}" in \
                    v6)   gzip -d /tmp/webproc_armv6.gz > /usr/local/bin/webproc   ;; \
                    v7)   gzip -d /tmp/webproc_armv7.gz > /usr/local/bin/webproc   ;; \
                    v8)   gzip -d /tmp/webproc_arm64.gz > /usr/local/bin/webproc   ;; \
                    *) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
                esac;  ;; \
            *) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
        esac  && \
        rm -rf /tmp/webproc_*.gz && \
        chmod +x /usr/local/bin/webproc && \
        apk del .build-deps && \
        mkdir -p /etc/default/ && \
        echo -e "ENABLED=1\nIGNORE_RESOLVCONF=yes" > /etc/default/dnsmasq &&\
        mkdir -p /etc/services.d/dnsmasq && \
        cp /tmp/dnsmasq_run.sh /etc/services.d/webproc/run \
        ; \
    fi

# Things to copy this to any Stage 2: Final image (e.g., ENV, LABEL, EXPOSE, WORKDIR, VOLUME, CMD)
EXPOSE 53/udp 8080
# ENTRYPOINT ["webproc","--configuration-file","/etc/dnsmasq.conf","--","dnsmasq","--no-daemon"]

# -------------------------------------------------------------------------------------------------
# Stage 2: Final image
# -------------------------------------------------------------------------------------------------

    # by using 'base' (which was set earlier, this image inherets any already set ENV/LABEL
FROM base
# Copy the entire filesystem from the builder stage
COPY --from=rootfs-stage / /

# Things to copy this to any Stage 2: Final image (e.g., ENV, LABEL, EXPOSE, WORKDIR, VOLUME, CMD)
EXPOSE 53/udp 8080

# Run the desired programs
ENTRYPOINT ["/init"]
