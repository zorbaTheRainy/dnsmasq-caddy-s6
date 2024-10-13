# Define the build argument (can be basic alpine for just dnsmasq/webproc,  or also caddy-alpine; tailscale can be added as S6 docker mod)
    # Alpine docker image    ->  https://hub.docker.com/_/alpine
    # S6 Overlay             ->  https://github.com/just-containers/s6-overlay
    # dnsmasq/webproc docker ->  https://github.com/jpillora/docker-dnsmasq
    # Caddy docker image     ->  https://hub.docker.com/_/caddy
    # Tailscale Docker Mod   ->  https://github.com/tailscale-dev/docker-mod

# -------------------------------------------------------------------------------------------------
# Stage 0: Create base image and set ENV/LABELS
# -------------------------------------------------------------------------------------------------

# set this up to copy files from the official Caddy image ( saves us worrying about the ${CADDY_VERSION} or ${TARGETARCH} )
# NOTE: Docker doesn’t directly substitute environment variables in the --from part of the COPY instruction.  We have to use FROM (and up here not below) to handle this
ARG CADDY_VERSION=2.8.1
FROM caddy:${CADDY_VERSION}-alpine AS caddy_donor

# set our actual BASE_IMAGE
FROM alpine:latest AS base

# passed via GitHub Action
ARG BUILD_TIME

# passed via GitHub Action (but used in Stage 1: Build)
# ARG S6_OVERLAY_VERSION=3.2.0.0
# ARG WEBPROC_VERSION=0.4.0

# Add labels to the image metadata
LABEL release-date=${BUILD_TIME}
LABEL source="https://github.com/zorbaTheRainy/docker-dnsmasq"

# -------------------------------------------------------------------------------------------------
# Stage 1: Build image
# -------------------------------------------------------------------------------------------------
FROM base AS rootfs_stage

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

# copy over files that run scripts  NOTE:  do NOT forget to chmod 755 them in the git folder (or they won't be executable in the image)
COPY 99-enable-services.sh /tmp/99-enable-services.sh
# COPY 99-enable-services_run /tmp/99-enable-services_run

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
    rm -f /tmp/s6-overlay-*.tar.xz && \
    mkdir -p /etc/services-available && \
    mkdir -p /etc/cont-init.d && \
    mv /tmp/99-enable-services.sh /etc/cont-init.d/99-enable-services.sh && \
    chmod 755 /etc/cont-init.d/99-enable-services.sh && \
    touch /s6_installed.txt \
    ; 

    # -------------------------------------------------------------------------------------------------
    # dnsmasq/webproc docker ->  https://github.com/jpillora/docker-dnsmasq
# -------------------------------------------------------------------------------------------------

# Inputs 
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
RUN apk update && \
    apk --no-cache add dnsmasq && \
    case "${TARGETARCH}" in \
        amd64)  gzip -d -c /tmp/webproc_amd64.gz > /usr/local/bin/webproc   ;; \
        arm64)  gzip -d -c /tmp/webproc_arm64.gz > /usr/local/bin/webproc   ;; \
        arm) \
            case "${TARGETVARIANT}" in \
                v6)   gzip -d -c /tmp/webproc_armv6.gz > /usr/local/bin/webproc   ;; \
                v7)   gzip -d -c /tmp/webproc_armv7.gz > /usr/local/bin/webproc   ;; \
                v8)   gzip -d -c /tmp/webproc_arm64.gz > /usr/local/bin/webproc   ;; \
                *) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
            esac;  ;; \
        *) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
    esac  && \
    rm -rf /tmp/webproc_* && \
    chmod +x /usr/local/bin/webproc && \
    mkdir -p /etc/default/ && \
    echo -e "ENABLED=1\nIGNORE_RESOLVCONF=yes" > /etc/default/dnsmasq &&\
    mkdir -p /etc/services.d/dnsmasq && \
    mv /tmp/dnsmasq_run.sh /etc/services.d/dnsmasq/run \
    ; 

RUN if [ -f "/etc/cont-init.d/99-enable-services.sh" ]; then \
        echo 'enable_service "${ENABLE_DNSMASQ}" "dnsmasq" "DNSmasq with WebProc"' >> /etc/cont-init.d/99-enable-services.sh ; \
    fi


# Things to copy this to any Stage 2: Final image (e.g., ENV, LABEL, EXPOSE, WORKDIR, VOLUME, CMD)
EXPOSE 53/udp 8080
# ENTRYPOINT ["webproc","--configuration-file","/etc/dnsmasq.conf","--","dnsmasq","--no-daemon"]

    # -------------------------------------------------------------------------------------------------
    # Caddy docker image     ->  https://hub.docker.com/_/caddy
# -------------------------------------------------------------------------------------------------

# Inputs 
ARG INCLUDE_CADDY=true
# ARG CADDY_VERSION=2.8.1
LABEL CADDY_VERSION=${CADDY_VERSION}

# All of this is copied (with edits) from the Caddy Dockerfile (https://raw.githubusercontent.com/caddyserver/caddy-docker/refs/heads/master/Dockerfile.tmpl)
RUN apk add --no-cache \
	ca-certificates \
	libcap \
	mailcap

RUN mkdir -p /config/caddy /data/caddy /etc/caddy /usr/share/caddy 

# copy files from the official Caddy image ( saves us worrying about the ${CADDY_VERSION} or ${TARGETARCH} )
COPY --from=caddy_donor /etc/caddy/Caddyfile /etc/caddy/Caddyfile
COPY --from=caddy_donor /usr/share/caddy/index.html /usr/share/caddy/index.html
COPY --from=caddy_donor /usr/bin/caddy /usr/bin/caddy

RUN set -eux; \
	setcap cap_net_bind_service=+ep /usr/bin/caddy; \
	chmod +x /usr/bin/caddy; \
	caddy version

# copy over files that run scripts  NOTE:  do NOT forget to chmod 755 them in the git folder (or they won't be executable in the image)
COPY caddy_run.sh /tmp/caddy_run.sh
RUN mkdir -p /etc/services-available/caddy && \
    mv /tmp/caddy_run.sh /etc/services-available/caddy/run && \
    chmod +x /etc/services-available/caddy/run && \
    if [ -f "/etc/cont-init.d/99-enable-services.sh" ]; then \
        echo 'enable_service "${ENABLE_CADDY}" "caddy" "Caddy reverse proxy"' >> /etc/cont-init.d/99-enable-services.sh ; \
    fi

# Things to copy to any Stage 2: Final image (e.g., ENV, LABEL, EXPOSE, WORKDIR, VOLUME, CMD)
ENV CADDY_VERSION v${CADDY_VERSION}
ENV XDG_CONFIG_HOME /configuration
ENV XDG_DATA_HOME /data
EXPOSE 80
EXPOSE 443
EXPOSE 443/udp
EXPOSE 2019
# CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]

# -------------------------------------------------------------------------------------------------
# Stage 2: Final image
# -------------------------------------------------------------------------------------------------

# by using 'base' (which was set earlier, this image inherets any already set ENV/LABEL in Stage 0)
FROM base
# Copy the entire filesystem from the builder stage
COPY --from=rootfs_stage / /

# enable variables
ENV ENABLE_DNSMASQ true
ENV ENABLE_CADDY true

# Things copied from an old Stage 1: Build image (e.g., ENV, LABEL, EXPOSE, WORKDIR, VOLUME, CMD)
ARG S6_OVERLAY_VERSION=3.2.0.0
LABEL S6_OVERLAY_VERSION=${S6_OVERLAY_VERSION}
ARG WEBPROC_VERSION=0.4.0
LABEL WEBPROC_VERSION=${WEBPROC_VERSION}
EXPOSE 53/udp 8080
ARG CADDY_VERSION=2.8.1
LABEL CADDY_VERSION=${CADDY_VERSION}
ENV CADDY_VERSION v${CADDY_VERSION}
ENV XDG_CONFIG_HOME /config
ENV XDG_DATA_HOME /data
EXPOSE 80
EXPOSE 443
EXPOSE 443/udp
EXPOSE 2019

# Run the desired programs
ENTRYPOINT ["/init"]
