FROM alpine

ARG TARGETARCH
ARG TARGETBRANCH
ARG BUILD_TIME
ARG WEBPROC_VERSION=0.4.0

ENV WEBPROC_URL_AMD64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_amd64.gz
ENV WEBPROC_URL_ARM64 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_arm64.gz
ENV WEBPROC_URL_ARMv7 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv7.gz
ENV WEBPROC_URL_ARMv6 https://github.com/jpillora/webproc/releases/download/v$WEBPROC_VERSION/webproc_${WEBPROC_VERSION}_linux_armv6.gz
ENV WEBPROC_URL https://github.com/jpillora/webproc/releases/download/v${WEBPROC_VERSION}/webproc_${WEBPROC_VERSION}_linux_${TARGETARCH}.gz

LABEL maintainer="dev@jpillora.com, and forked by ZorbaTheRainy"
LABEL release-date=${BUILD_TIME}
LABEL source="https://github.com/zorbaTheRainy/docker-dnsmasq"


# webproc release settings
COPY dnsmasq.conf /etc/dnsmasq.conf
# fetch dnsmasq and webproc binary
# remember "arm/v7" has the TARGETARCH of just "arm", and TARGETVARIANT store the "v7" information. 
RUN apk update \
	&& apk --no-cache add dnsmasq \
	&& apk add --no-cache --virtual .build-deps curl \
	&& echo "WEBPROC_URL: ${WEBPROC_URL}" \
	&& echo "TARGETARCH:  ${TARGETARCH}" \
	&& if [ "$TARGETARCH" = "arm" ]; then \
    if [ "$TARGETVARIANT" = "v6" ]; then \
        curl -sL $WEBPROC_URL_ARMv6 | gzip -d - > /usr/local/bin/webproc  ; \
    elif [ "$TARGETVARIANT" = "v7" ]; then \
        curl -sL $WEBPROC_URL_ARMv7 | gzip -d - > /usr/local/bin/webproc  ; \
    elif [ "$TARGETVARIANT" = "v8" ]; then \
        curl -sL $WEBPROC_URL_ARM64 | gzip -d - > /usr/local/bin/webproc  ; \
    else \
        curl -sL $WEBPROC_URL_ARMv7 | gzip -d - > /usr/local/bin/webproc  ; \
    fi \
else \
curl -sL $WEBPROC_URL | gzip -d - > /usr/local/bin/webproc  ; \
fi \
	&& chmod +x /usr/local/bin/webproc \
	&& apk del .build-deps 

#configure dnsmasq
RUN mkdir -p /etc/default/
RUN echo -e "ENABLED=1\nIGNORE_RESOLVCONF=yes" > /etc/default/dnsmasq

EXPOSE 53/udp 8080

# launch webproc, which in turn launches dnsmasq
ENTRYPOINT ["webproc","--configuration-file","/etc/dnsmasq.conf","--","dnsmasq","--no-daemon"]
