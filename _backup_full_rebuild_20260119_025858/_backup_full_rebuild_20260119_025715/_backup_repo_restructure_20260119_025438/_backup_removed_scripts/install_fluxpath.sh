#!/usr/bin/env bash
set -e

BASE_DIR="/home/syko/FluxPath"
VENV_DIR="$BASE_DIR/venv"
SERVICE_NAME="fluxpath"
PYTHON_BIN="/usr/bin/python3"
SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install fastapi uvicorn[standard]

cat << 'EOF' | sudo tee "$SYSTEMD_UNIT" > /dev/null
[Unit]
Description=FluxPath Backend Service
After=network.target

[Service]
Type=simple
User=syko
WorkingDirectory=/home/syko/FluxPath
ExecStart=/home/syko/FluxPath/venv/bin/python -m fluxpath.server
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo "FluxPath backend installed and started."
