#!/bin/bash

echo "=== FluxPath Unified Backend Setup ==="

BASE_DIR="/home/sy/FluxPath"
VENV_DIR="$BASE_DIR/venv"
LEGACY_SERVER="$BASE_DIR/fluxpath/device/server.py"
NEW_SERVER="$BASE_DIR/server.py"

echo "Stopping any running legacy server on port 9876..."
sudo fuser -k 9876/tcp 2>/dev/null

echo "Killing any python process running fluxpath.device.server..."
pkill -f "fluxpath.device.server"

echo "Disabling legacy server module..."
if [ -f "$LEGACY_SERVER" ]; then
    mv "$LEGACY_SERVER" "$LEGACY_SERVER.disabled"
    echo "Renamed legacy server.py → server.py.disabled"
else
    echo "Legacy server.py already disabled or missing."
fi

echo "Removing __pycache__..."
rm -rf "$BASE_DIR/fluxpath/device/__pycache__"

echo "Ensuring FastAPI + Uvicorn are installed..."
source "$VENV_DIR/bin/activate"
pip install fastapi uvicorn

echo "Creating new FastAPI backend at $NEW_SERVER..."
cat > "$NEW_SERVER" << 'EOF'
from fastapi import FastAPI, WebSocket
from fastapi.responses import JSONResponse
import uvicorn

app = FastAPI()

@app.get("/fluxpath/capabilities")
async def capabilities():
    return JSONResponse({
        "name": "FluxPath",
        "version": "1.0",
        "mmu": True,
        "ws": "/fluxpath/ws"
    })

@app.websocket("/fluxpath/ws")
async def fluxpath_ws(websocket: WebSocket):
    await websocket.accept()
    await websocket.send_json({"status": "connected"})
    while True:
        await websocket.send_json({"ping": "ok"})

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=9876)
EOF

echo "Creating systemd service..."
SERVICE_FILE="/etc/systemd/system/fluxpath.service"

sudo bash -c "cat > $SERVICE_FILE" << EOF
[Unit]
Description=FluxPath LAN Device Backend
After=network.target

[Service]
Type=simple
User=sy
WorkingDirectory=$BASE_DIR
ExecStart=$VENV_DIR/bin/python $NEW_SERVER
Restart=always
RestartSec=3
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Enabling FluxPath service..."
sudo systemctl enable fluxpath.service

echo "Starting FluxPath service..."
sudo systemctl start fluxpath.service

echo "Checking service status..."
sudo systemctl status fluxpath.service --no-pager

echo "Verifying port 9876..."
sudo ss -tulpn | grep 9876 || echo "Port 9876 is free."

echo "=== FluxPath backend setup complete ==="
