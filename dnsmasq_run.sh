#!/command/execlineb -P

# Ensure the necessary directories exist
mkdir -p /var/run/s6/etc

# Run the webproc command with the specified configuration
webproc --configuration-file /etc/dnsmasq.conf -- dnsmasq --no-daemon