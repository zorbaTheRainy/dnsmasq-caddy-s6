#!/command/execlineb -P
with-contenv

s6-envdir /etc/envs
s6-echo Enable: ${ENABLE_CADDY}

# Debugging: Check if ENABLE_CADDY is set
if { s6-test ${ENABLE_CADDY} = "" }
    foreground {
      s6-echo ENABLE_CADDY is not set!
      exit 1
    }

# Check if ENABLE_CADDY is 1 or true (case insensitive)
if { s6-test ${ENABLE_CADDY} -eq 1 }
    foreground {
        s6-envdir /etc/envs s6-echo ENABLE_CADDY = true
        s6-export ENABLE_CADDY true
    }

if { s6-test ${ENABLE_CADDY} -eq 0 }
    foreground {
        s6-envdir /etc/envs s6-echo ENABLE_CADDY = false
        s6-export ENABLE_CADDY false
    }

foreground {
    # Convert ENABLE_CADDY to lowercase for comparison
    s6-envdir /etc/envs ENABLE_CADDY_LOWER $(echo ${ENABLE_CADDY} | tr '[:upper:]' '[:lower:]')

    # Perform the actual check
    if { s6-test ${ENABLE_CADDY_LOWER} = "true" }
        s6-echo '[run] enabling Caddy reverse proxy'
        
        if { s6-test -d /etc/services.d/caddy }
            s6-echo '[run] Caddy reverse proxy already enabled'
        else
            ln -s /etc/services-available/caddy /etc/services.d/caddy
        fi
    fi

    rm /etc/services.d/99-enable-services/run
}
