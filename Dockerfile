# Define the build argument (can be basic alpine for just dnsmasq/webproc,  or also caddy-alpine; tailscale can be added as S6 docker mod)
ARG BASE_IMAGE=alpine:latest
FROM ${BASE_IMAGE}

# inherent in the build system
ARG TARGETARCH
ARG TARGETVARIANT

# passed via GitHub Action
ARG BUILD_TIME
ARG IS_S6=false
ARG WEBPROC_VERSION=0.4.0
ARG S6_OVERLAY_VERSION=3.2.0.0
ARG BASE_IMAGE_TMP

# Set up URLs, which are dynamically created based on the version desired
ENV WEBPROC_URL_AMD64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_amd64.gz
ENV WEBPROC_URL_ARM64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_arm64.gz
ENV WEBPROC_URL_ARMv7 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv7.gz
ENV WEBPROC_URL_ARMv6 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv6.gz

ENV S6_URL_AMD64      https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz
ENV S6_URL_ARM64      https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-aarch64.tar.xz
ENV S6_URL_ARMv7      https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-arm.tar.xz
ENV S6_URL_ARMv6      https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-armhf.tar.xz

# Add labels to the image metadata
LABEL BASE_IMAGE=${BASE_IMAGE_TMP}
LABEL WEBPROC_VERSION=${WEBPROC_VERSION}
LABEL IS_S6=${IS_S6}
LABEL S6_OVERLAY_VERSION=${S6_OVERLAY_VERSION}
LABEL release-date=${BUILD_TIME}
LABEL source="https://github.com/zorbaTheRainy/docker-dnsmasq"
LABEL maintainer="dev@jpillora.com, and forked by ZorbaTheRainy"


# copy over files that run scripts  NOTE:  do NOT forget to chmod 755 them in the git folder (or they won't be executable in the image)
COPY keep_alive.sh /etc/keep_alive.sh
COPY start.sh /etc/start.sh

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
    echo -e "ENABLED=1\nIGNORE_RESOLVCONF=yes" > /etc/default/dnsmasq

# Conditionally add s6 overlay
RUN if [ "$is_s6" = "true" ]; then \
        apk update && \
        apk add --no-cache curl xz-utils && \
        curl -L -o /tmp/s6-overlay-noarch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz && \
        case "${TARGETARCH}" in \
            amd64)  curl -L -o /tmp/s6-overlay-yesarch.tar.xz $S6_URL_AMD64 ;; \
            arm64)  curl -L -o /tmp/s6-overlay-yesarch.tar.xz $S6_URL_ARM64 ;; \
            arm) \
                case "${TARGETVARIANT}" in \
                    v6)   curl -L -o /tmp/s6-overlay-yesarch.tar.xz $S6_URL_ARMv6 ;; \
                    v7)   curl -L -o /tmp/s6-overlay-yesarch.tar.xz $S6_URL_ARMv7 ;; \
                    v8)   curl -L -o /tmp/s6-overlay-yesarch.tar.xz $S6_URL_ARM64 ;; \
                    *) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
                esac ;; \
            *) echo >&2 "error: unsupported architecture (${TARGETARCH}/${TARGETVARIANT})"; exit 1 ;; \
        esac && \
        tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
        tar -C / -Jxpf /tmp/s6-overlay-yesarch.tar.xz && \
        rm -rf /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-yesarch.tar.xz && \
        mkdir /init \
        touch /app/s6_installed.txt \
        ; \
    else \
        mkdir /init \
        ; \
    fi


EXPOSE 53/udp 8080

# Run the desired programs
  # runs dnsmasq/webproc and caddy (if it is installed)
CMD ["/etc/start.sh"]
  # runs S6
ENTRYPOINT ["/init"]
