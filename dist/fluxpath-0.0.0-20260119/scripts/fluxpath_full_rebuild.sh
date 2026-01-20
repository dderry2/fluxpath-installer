#!/bin/bash

echo "=== FluxPath Full Rebuild Script ==="

BASE_DIR="/home/syko/FluxPath"
VENV_DIR="$BASE_DIR/venv"
BACKUP_DIR="$BASE_DIR/_backup_full_rebuild_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

echo "Backup directory: $BACKUP_DIR"
echo

# ---------------------------------------------------------
# 1. Kill legacy server + free port
# ---------------------------------------------------------
echo "--- Stopping legacy server ---"
sudo fuser -k 9876/tcp 2>/dev/null
pkill -f "fluxpath.device.server" 2>/dev/null || true

if [ -f "$BASE_DIR/fluxpath/device/server.py" ]; then
    echo "Moving legacy fluxpath/device/server.py → $BACKUP_DIR"
    mv "$BASE_DIR/fluxpath/device/server.py" "$BACKUP_DIR/server.py.legacy"
fi

rm -rf "$BASE_DIR/fluxpath/device/__pycache__"
echo

# ---------------------------------------------------------
# 2. Remove stale __pycache__ everywhere
# ---------------------------------------------------------
echo "--- Removing all __pycache__ directories ---"
find "$BASE_DIR" -type d -name "__pycache__" -exec rm -rf {} +
echo

# ---------------------------------------------------------
# 3. Clean up old installers, Moonraker, prototypes
# ---------------------------------------------------------
echo "--- Cleaning legacy installers and prototypes ---"

REMOVE_PATTERNS=(
    "FluxPath_Installer_v*.sh"
    "install_fluxpath*.sh"
    "fluxpath_installer.sh"
    "*moonraker*"
    "*Service*"
    "mmu_old"
    "mmu_prototype"
    "mmu_test"
)

for pattern in "${REMOVE_PATTERNS[@]}"; do
    for file in "$BASE_DIR"/$pattern; do
        if [ -e "$file" ]; then
            echo "Moving $file → $BACKUP_DIR"
            mv "$file" "$BACKUP_DIR/"
        fi
    done
done
echo

# ---------------------------------------------------------
# 4. Create modern repo structure
# ---------------------------------------------------------
echo "--- Creating modern repo structure ---"

mkdir -p "$BASE_DIR/scripts"
mkdir -p "$BASE_DIR/systemd"
mkdir -p "$BASE_DIR/tools"
mkdir -p "$BASE_DIR/docs"
mkdir -p "$BASE_DIR/legacy"
mkdir -p "$BASE_DIR/tests"

echo

# ---------------------------------------------------------
# 5. Move scripts into /scripts
# ---------------------------------------------------------
echo "--- Organizing scripts ---"

SCRIPT_PATTERNS=(
    "*backend*.sh"
    "*fluxpath*.sh"
    "*upgrade*.sh"
    "*disable*.sh"
    "*kill*.sh"
)

for pattern in "${SCRIPT_PATTERNS[@]}"; do
    for file in "$BASE_DIR"/$pattern; do
        if [ -f "$file" ]; then
            echo "Moving $file → scripts/"
            mv "$file" "$BASE_DIR/scripts/"
        fi
    done
done
echo

# ---------------------------------------------------------
# 6. Move docs into /docs
# ---------------------------------------------------------
echo "--- Organizing documentation ---"

DOC_PATTERNS=(
    "README.md"
    "CHANGELOG.md"
    "docs/*"
)

for pattern in "${DOC_PATTERNS[@]}"; do
    for file in $BASE_DIR/$pattern; do
        if [ -e "$file" ]; then
            echo "Moving $file → docs/"
            mv "$file" "$BASE_DIR/docs/" 2>/dev/null || true
        fi
    done
done
echo

# ---------------------------------------------------------
# 7. Backup unknown top-level files
# ---------------------------------------------------------
echo "--- Backing up unknown files ---"

for file in "$BASE_DIR"/*; do
    case "$file" in
        "$BASE_DIR/scripts" | "$BASE_DIR/systemd" | "$BASE_DIR/tools" | "$BASE_DIR/docs" | "$BASE_DIR/legacy" | "$BASE_DIR/tests" | "$BASE_DIR/fluxpath" | "$BASE_DIR/core" | "$BASE_DIR/fp_core" | "$BASE_DIR/mmu" | "$BASE_DIR/server.py" | "$BASE_DIR/venv" | "$BASE_DIR/pyproject.toml" | "$BASE_DIR/__init__.py" )
            ;;
        *)
            if [ -e "$file" ]; then
                echo "Backing up $file → $BACKUP_DIR"
                mv "$file" "$BACKUP_DIR/"
            fi
            ;;
    esac
done
echo

# ---------------------------------------------------------
# 8. Install FastAPI backend (server.py)
# ---------------------------------------------------------
echo "--- Installing FastAPI backend ---"

if [ -f "$VENV_DIR/bin/activate" ]; then
    source "$VENV_DIR/bin/activate"
fi

"$VENV_DIR/bin/pip" install fastapi uvicorn

cat > "$BASE_DIR/server.py" << 'EOF'
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse, HTMLResponse
import uvicorn
import asyncio
from typing import List

app = FastAPI(title="FluxPath Backend")

printer_state = {
    "name": "FluxPath Virtual Printer",
    "model": "FluxPath-MMU",
    "firmware": "1.0.0",
    "status": "idle",
    "job": None,
    "mmu": {
        "enabled": True,
        "slots": 4,
        "active_slot": 1,
        "filaments": [
            {"slot": 1, "color": "red", "material": "PLA"},
            {"slot": 2, "color": "blue", "material": "PLA"},
            {"slot": 3, "color": "green", "material": "PLA"},
            {"slot": 4, "color": "yellow", "material": "PLA"},
        ],
    },
}

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except:
                self.disconnect(connection)

manager = ConnectionManager()

DASHBOARD_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>FluxPath Dashboard</title>
    <style>
        body { font-family: sans-serif; background: #111; color: #eee; padding: 20px; }
        h1 { color: #4fd1c5; }
        .card { background: #1a202c; padding: 16px; border-radius: 8px; margin-bottom: 16px; }
        .label { color: #a0aec0; font-size: 0.9em; }
        .value { font-size: 1.1em; }
        code { background: #2d3748; padding: 2px 4px; border-radius: 4px; }
    </style>
</head>
<body>
    <h1>FluxPath Backend</h1>
    <div class="card">
        <div class="label">Health</div>
        <div class="value" id="health">Loading...</div>
    </div>
    <div class="card">
        <div class="label">Printer Status</div>
        <pre id="printer-status">{}</pre>
    </div>
    <div class="card">
        <div class="label">WebSocket</div>
        <div class="value" id="ws-status">Connecting...</div>
    </div>
    <script>
        async function fetchHealth() {
            try {
                const res = await fetch('/health');
                const data = await res.json();
                document.getElementById('health').innerText = data.status;
            } catch (e) {
                document.getElementById('health').innerText = 'error';
            }
        }

        async function fetchPrinterStatus() {
            try {
                const res = await fetch('/printer/status');
                const data = await res.json();
                document.getElementById('printer-status').innerText = JSON.stringify(data, null, 2);
            } catch (e) {
                document.getElementById('printer-status').innerText = 'error';
            }
        }

        function connectWS() {
            const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/fluxpath/ws');
            ws.onopen = () => {
                document.getElementById('ws-status').innerText = 'connected';
            };
            ws.onclose = () => {
                document.getElementById('ws-status').innerText = 'disconnected (retrying...)';
                setTimeout(connectWS, 2000);
            };
            ws.onmessage = (event) => {};
        }

        fetchHealth();
        fetchPrinterStatus();
        connectWS();
        setInterval(fetchHealth, 5000);
        setInterval(fetchPrinterStatus, 5000);
    </script>
</body>
</html>
"""

@app.get("/")
async def dashboard():
    return HTMLResponse(DASHBOARD_HTML)

@app.get("/health")
async def health():
    return JSONResponse({"status": "ok"})

@app.get("/printer/info")
async def printer_info():
    return JSONResponse({
        "name": printer_state["name"],
        "model": printer_state["model"],
        "firmware": printer_state["firmware"],
        "mmu": printer_state["mmu"]["enabled"],
    })

@app.get("/printer/status")
async def printer_status():
    return JSONResponse({
        "status": printer_state["status"],
        "job": printer_state["job"],
        "mmu": printer_state["mmu"],
    })

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
    await manager.connect(websocket)
    try:
        await websocket.send_json({"status": "connected", "source": "fluxpath"})
        while True:
            await manager.broadcast({
                "type": "status",
                "status": printer_state["status"],
                "mmu": printer_state["mmu"],
            })
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=9876)
EOF

echo

# ---------------------------------------------------------
# 9. Install systemd service
# ---------------------------------------------------------
echo "--- Installing systemd service ---"

SERVICE_FILE="/etc/systemd/system/fluxpath.service"

sudo bash -c "cat > $SERVICE_FILE" << EOF
[Unit]
Description=FluxPath LAN Device Backend
After=network.target

[Service]
Type=simple
User=syko
WorkingDirectory=$BASE_DIR
ExecStart=$VENV_DIR/bin/python $BASE_DIR/server.py
Restart=always
RestartSec=3
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable fluxpath.service
sudo systemctl restart fluxpath.service

echo

# ---------------------------------------------------------
# 10. Verify
# ---------------------------------------------------------
echo "--- Checking service status ---"
sudo systemctl status fluxpath.service --no-pager

echo "--- Checking port 9876 ---"
sudo ss -tulpn | grep 9876 || echo "Port 9876 is free (unexpected)."

echo
echo "=== FluxPath Full Rebuild Complete ==="
echo "Open:  http://<machine-ip>:9876/"
echo "OrcaSlicer: http://<machine-ip>:9876/fluxpath/capabilities"
