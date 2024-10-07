#!/command/execlineb -P
with-contenv

# abort the script fi the below is 'false''
if { s6-echo ${ENABLE_DNSMASQ} | s6-lowercase | s6-test -eq 1 -o s6-test -eq true }

# Run the webproc command with the specified configuration
/usr/local/bin/webproc --configuration-file /etc/dnsmasq.conf -- dnsmasq --no-daemon