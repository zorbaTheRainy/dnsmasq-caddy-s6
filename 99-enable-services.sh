#!/bin/bash
with-contenv

    # -------------------------------------------------------------------------------------------------
    # Caddy docker image     ->  https://hub.docker.com/_/caddy
# -------------------------------------------------------------------------------------------------

echo "Enable: ${ENABLE_CADDY}"

# Check if ENABLE_CADDY is 1 or true (case insensitive)
# Debugging: Check if ENABLE_CADDY is set
if [ -z "${ENABLE_CADDY}" ]; then
  echo "ENABLE_CADDY is not set!"
  exit 1
fi

# Check if ENABLE_CADDY is 1 or true (case insensitive)
if [ "${ENABLE_CADDY}" -eq 1 ] 2>/dev/null; then
  ENABLE_CADDY="true"
elif [ "${ENABLE_CADDY}" -eq 0 ] 2>/dev/null; then
  ENABLE_CADDY="false"
fi

# Convert ENABLE_CADDY to lowercase for comparison
ENABLE_CADDY_LOWER=$(echo "${ENABLE_CADDY}" | tr '[:upper:]' '[:lower:]')

# perform the actual check
if [ "${ENABLE_CADDY_LOWER}" == "true" ]; then
  echo '[run] enabling Caddy reverse proxy'

  # Enable nginx as a supervised service
  if [ -d /etc/services.d/caddy ]
  then
    echo '[run] Caddy reverse proxy already enabled'
  else
    ln -s /etc/services-available/caddy /etc/services.d/caddy
  fi
fi
