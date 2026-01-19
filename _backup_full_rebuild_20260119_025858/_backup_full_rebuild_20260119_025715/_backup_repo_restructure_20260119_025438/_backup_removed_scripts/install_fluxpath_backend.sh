#!/usr/bin/env bash
set -e

# --- CONFIG ---
USER_NAME="syko"
BASE_DIR="/home/${USER_NAME}/FluxPath"
VENV_DIR="${BASE_DIR}/venv"
SERVICE_NAME="fluxpath"
PYTHON_BIN="/usr/bin/python3"
SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
PORT="9999"
# --------------

echo "==> Preparing FluxPath backend structure..."

mkdir -p "${BASE_DIR}/fluxpath/core"

# Ensure package init files exist
if [ ! -f "${BASE_DIR}/fluxpath/__init__.py" ]; then
  echo '__version__ = "0.1.0"' > "${BASE_DIR}/fluxpath/__init__.py"
fi

if [ ! -f "${BASE_DIR}/fluxpath/core/__init__.py" ]; then
  touch "${BASE_DIR}/fluxpath/core/__init__.py"
fi

# Move backend files into correct package locations
[ -f "${BASE_DIR}/api.py" ] && mv "${BASE_DIR}/api.py" "${BASE_DIR}/fluxpath/api.py"
[ -f "${BASE_DIR}/server.py" ] && mv "${BASE_DIR}/server.py" "${BASE_DIR}/fluxpath/server.py"
[ -f "${BASE_DIR}/diagnostics.py" ] && mv "${BASE_DIR}/diagnostics.py" "${BASE_DIR}/fluxpath/core/diagnostics.py"
[ -f "${BASE_DIR}/instances.py" ] && mv "${BASE_DIR}/instances.py" "${BASE_DIR}/fluxpath/core/instances.py"

echo "==> Ensuring Python virtual environment..."

if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install fastapi uvicorn[standard]

echo "==> Writing systemd service..."

cat << EOF | sudo tee "$SYSTEMD_UNIT" > /dev/null
[Unit]
Description=FluxPath Backend Service
After=network.target

[Service]
Type=simple
User=${USER_NAME}
WorkingDirectory=${BASE_DIR}
ExecStart=${VENV_DIR}/bin/python -m fluxpath.server
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "==> Reloading systemd and starting service..."

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo ""
echo "=============================================="
echo " FluxPath backend installed and running!"
echo " Test it with:"
echo "   curl -s http://192.168.0.122:${PORT}/fluxpath/version"
echo "=============================================="
