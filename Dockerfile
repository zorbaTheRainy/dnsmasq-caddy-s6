# Define the build argument
ARG BASE_IMAGE=alpine:latest

# Use the argument in the FROM instruction
FROM ${BASE_IMAGE}

ARG TARGETARCH
ARG TARGETVARIANT

ARG BUILD_TIME # passed via GitHub Action
ARG IS_S6=false # passed via GitHub Action
ARG BASE_IMAGE_TMP  # passed via GitHub Action

ARG WEBPROC_VERSION=0.4.0
ARG S6_OVERLAY_VERSION=3.2.0.0


ENV WEBPROC_URL_AMD64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_amd64.gz
ENV WEBPROC_URL_ARM64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_arm64.gz
ENV WEBPROC_URL_ARMv7 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv7.gz
ENV WEBPROC_URL_ARMv6 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv6.gz

LABEL BASE_IMAGE=${BASE_IMAGE_TMP}
LABEL IS_S6=${IS_S6}
LABEL WEBPROC_VERSION=${WEBPROC_VERSION}
LABEL S6_OVERLAY_VERSION=${S6_OVERLAY_VERSION}
LABEL release-date=${BUILD_TIME}
LABEL source="https://github.com/zorbaTheRainy/docker-dnsmasq"
LABEL maintainer="dev@jpillora.com, and forked by ZorbaTheRainy"


# webproc release settings
COPY dnsmasq.conf /etc/dnsmasq.conf
# fetch dnsmasq and webproc binary
RUN apk update && \
	apk --no-cache add dnsmasq && \
	apk add --no-cache --virtual .build-deps curl && \
	echo "WEBPROC_URL: ${WEBPROC_URL}" && \
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
        apt-get update && apt-get install -y \
        curl \
        xz-utils \
        ; \
        curl -L -o /tmp/s6-overlay-noarch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz && \
        curl -L -o /tmp/s6-overlay-x86_64.tar.xz https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${TARGETARCH}.tar.xz && \
        tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
        tar -C / -Jxpf /tmp/s6-overlay-${TARGETARCH}.tar.xz &&  \
        rm -rf /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-${TARGETARCH}.tar.xz
    fi

EXPOSE 53/udp 8080

# launch webproc, which in turn launches dnsmasq
# ENTRYPOINT ["webproc","--configuration-file","/etc/dnsmasq.conf","--","dnsmasq","--no-daemon"]
ENTRYPOINT ["/init"]
