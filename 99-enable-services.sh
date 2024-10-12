#!/usr/bin/with-contenv sh

enable_service() {
  local enable_flag="$1"
  local service_name="$2"
  local description="$3"

  # convert int to str
  if [ "${enable_flag}" -eq 1 ] 2>/dev/null; then
    enable_flag="true"
  elif [ "${enable_flag}" -eq 0 ] 2>/dev/null; then
    enable_flag="false"
  fi

  # Convert enable_flag to lowercase for comparison
  enable_flag_lower=$(echo "${enable_flag}" | tr '[:upper:]' '[:lower:]')

  # perform the actual check
  if [ "${enable_flag_lower}" == "true" ]; then
    echo "[enable-services] enabling ${description}"

    # Enable supervised service
    if [ -d /etc/services.d/${service_name} ]
    then
      echo "[enable-services] ${description} already enabled"
    else
      ln -s /etc/services-available/${service_name} /etc/services.d/${service_name}
    fi
  else
    echo "[enable-services] disabled ${description}"
  fi
}

# Example calls for two services with description and using the environment variable ENABLE_CADDY
    # Caddy docker image     ->  https://hub.docker.com/_/caddy
enable_service "${ENABLE_CADDY}" "caddy" "Caddy reverse proxy"
