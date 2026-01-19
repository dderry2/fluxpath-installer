#!/bin/bash
set -e

echo "=== FluxPath Installer ==="

BASE_DIR="/home/$USER/FluxPath"
SERVICE_NAME="fluxpath.service"
PYTHON_BIN="python3"
VENV_DIR="$BASE_DIR/venv"

echo "→ Ensuring system dependencies are installed..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip git curl

echo "→ Creating project directory (if missing)..."
mkdir -p "$BASE_DIR"

echo "→ Copying FluxPath files into place..."
# Assumes installer is run from inside the repo root
cp -r . "$BASE_DIR"

cd "$BASE_DIR"

echo "→ Creating Python virtual environment..."
$PYTHON_BIN -m venv "$VENV_DIR"

echo "→ Activating venv and installing dependencies..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r pyproject.toml || pip install -r requirements.txt || true

echo "→ Installing systemd service..."
sudo cp systemd/fluxpath.service /etc/systemd/system/$SERVICE_NAME
sudo systemctl daemon-reload

echo "→ Enabling and starting FluxPath backend..."
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

echo "→ Waiting for backend to start..."
sleep 3

echo "→ Checking service status..."
sudo systemctl status $SERVICE_NAME --no-pager || true

echo "→ Verifying backend is responding on port 9876..."
if curl -s http://localhost:9876/health > /dev/null; then
    echo "✔ Backend is running and responding."
else
    echo "✖ Backend did not respond. Check logs:"
    echo "  sudo journalctl -u $SERVICE_NAME -f"
fi

echo "→ Checking MMU hardware..."
if lsusb | grep -i "serial" > /dev/null || dmesg | grep -i ttyUSB > /dev/null; then
    echo "✔ MMU hardware detected."
else
    echo "⚠ No MMU hardware detected. System will still run, but MMU operations may fail."
fi

echo "=== FluxPath installation complete ==="
echo "Access the backend at: http://<your-ip>:9876"
