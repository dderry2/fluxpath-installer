#!/usr/bin/env bash
set -e

USER_NAME="syko"
MOONRAKER_CONFIG="/home/${USER_NAME}/printer_data/config/moonraker.conf"
FLUXPATH_URL="http://127.0.0.1:9999"

if [ ! -f "$MOONRAKER_CONFIG" ]; then
  echo "Moonraker config not found at ${MOONRAKER_CONFIG}"
  exit 1
fi

# Add [http_client fluxpath] if missing
if ! grep -q "^

\[http_client fluxpath\]

" "$MOONRAKER_CONFIG"; then
  cat << EOF >> "$MOONRAKER_CONFIG"

[http_client fluxpath]
url: ${FLUXPATH_URL}
timeout: 5
EOF
  echo "Added [http_client fluxpath] to moonraker.conf"
else
  echo "[http_client fluxpath] already present in moonraker.conf"
fi

# Add a simple shell_command to test FluxPath
if ! grep -q "^

\[shell_command fluxpath_ping\]

" "$MOONRAKER_CONFIG"; then
  cat << 'EOF' >> "$MOONRAKER_CONFIG"

[shell_command fluxpath_ping]
command: curl -s http://127.0.0.1:9999/fluxpath/version
timeout: 5
EOF
  echo "Added [shell_command fluxpath_ping] to moonraker.conf"
else
  echo "[shell_command fluxpath_ping] already present in moonraker.conf"
fi

sudo systemctl restart moonraker
echo "Moonraker restarted. You can now call 'fluxpath_ping' via Moonraker."
