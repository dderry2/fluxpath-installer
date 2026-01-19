#!/bin/bash
set -e

BASE_DIR="/home/$USER/FluxPath"
SERVICE_NAME="fluxpath.service"
VENV_DIR="$BASE_DIR/venv"

echo "=== FluxPath Installer / Updater ==="

if [ -d "$BASE_DIR/.git" ]; then
    echo "→ Existing installation detected. Updating..."
    cd "$BASE_DIR"
    git pull --rebase
else
    echo "→ No installation found. Installing fresh copy..."
    mkdir -p "$BASE_DIR"
    cp -r . "$BASE_DIR"
    cd "$BASE_DIR"
    git init
    git remote add origin https://github.com/dderry2/fluxpath-installer
    git branch -M main
fi

echo "→ Ensuring system dependencies..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip git curl

if [ ! -d "$VENV_DIR" ]; then
    echo "→ Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

echo "→ Activating venv and installing dependencies..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r pyproject.toml || pip install -r requirements.txt || true

echo "→ Installing systemd service..."
sudo cp systemd/fluxpath.service /etc/systemd/system/$SERVICE_NAME
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

echo "→ Waiting for backend to start..."
sleep 3

echo "→ Checking backend health..."
if curl -s http://localhost:9876/health > /dev/null; then
    echo "✔ Backend is running."
else
    echo "✖ Backend not responding. Check logs:"
    echo "  sudo journalctl -u $SERVICE_NAME -f"
fi

echo "→ Checking MMU hardware..."
if lsusb | grep -i "serial" > /dev/null || dmesg | grep -i ttyUSB > /dev/null; then
    echo "✔ MMU hardware detected."
else
    echo "⚠ No MMU hardware detected."
fi

echo "=== FluxPath install/update complete ==="
