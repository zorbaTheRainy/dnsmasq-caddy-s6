#!/bin/sh

# Check if caddy is installed
if command -v caddy >/dev/null 2>&1; then
    # Set the working directory
    cd /srv

    # Run caddy if installed
    caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
fi

# Run webproc with dnsmasq
exec webproc --configuration-file /etc/dnsmasq.conf -- dnsmasq --no-daemon
