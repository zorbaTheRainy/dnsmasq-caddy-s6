#!/command/execlineb -P
with-contenv

# abort the script fi the below is 'false''
if { s6-echo ${ENABLE_CADDY} | s6-lowercase | s6-test -eq 1 -o s6-test -eq true }

# Change to the working directory
cd /srv

# Run Caddy with the specified configuration
/usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
