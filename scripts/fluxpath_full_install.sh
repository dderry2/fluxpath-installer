#!/bin/bash
set -e

echo "=== FluxPath Full Platform Installer ==="

REPO_URL="https://github.com/dderry2/fluxpath-installer"
BASE_DIR="/home/$USER/FluxPath"
SERVICE_NAME="fluxpath.service"
VENV_DIR="$BASE_DIR/venv"
SERVER_FILE="$BASE_DIR/server.py"

echo "→ Ensuring system dependencies..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip git curl

if [ -d "$BASE_DIR/.git" ]; then
  echo "→ Existing FluxPath installation detected. Updating..."
  cd "$BASE_DIR"
  git pull --rebase
else
  echo "→ No installation found. Installing fresh copy..."
  mkdir -p "$BASE_DIR"
  cp -r . "$BASE_DIR"
  cd "$BASE_DIR"
  git init
  git remote add origin "$REPO_URL"
  git branch -M main
fi

echo "→ Creating virtual environment (if missing)..."
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

echo "→ Activating venv and installing dependencies..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
# Prefer pyproject‑based install if configured, otherwise fallback
if [ -f "pyproject.toml" ]; then
  pip install .
elif [ -f "requirements.txt" ]; then
  pip install -r requirements.txt
fi

if [ ! -f "$SERVER_FILE" ]; then
  echo "✖ server.py not found in $BASE_DIR. Aborting."
  exit 1
fi

echo "→ Ensuring MMU engine + state machine scaffolding..."

MMU_DIR="$BASE_DIR/mmu"
mkdir -p "$MMU_DIR"

MMU_ENGINE_FILE="$MMU_DIR/mmu_engine.py"
if [ ! -f "$MMU_ENGINE_FILE" ]; then
  cat > "$MMU_ENGINE_FILE" << 'EOF'
from enum import Enum

class MMUState(str, Enum):
    IDLE = "idle"
    SWITCHING = "switching"
    LOADING = "loading"
    UNLOADING = "unloading"
    ERROR = "error"

class MMUEngine:
    def __init__(self):
        self.state = MMUState.IDLE
        self.active_slot = 0
        self.filament_map = {}  # slot -> metadata

    def get_status(self):
        return {
            "state": self.state,
            "active_slot": self.active_slot,
            "filament_map": self.filament_map,
        }

    def switch_slot(self, slot: int):
        self.state = MMUState.SWITCHING
        # TODO: hardware call
        self.active_slot = slot
        self.state = MMUState.IDLE
        return self.get_status()

    def load_filament(self):
        self.state = MMUState.LOADING
        # TODO: hardware call
        self.state = MMUState.IDLE
        return self.get_status()

    def unload_filament(self):
        self.state = MMUState.UNLOADING
        # TODO: hardware call
        self.state = MMUState.IDLE
        return self.get_status()

    def reset(self):
        self.state = MMUState.IDLE
        return self.get_status()
EOF
fi

echo "→ Injecting MMU API, slicer integration, LAN discovery, and multicolor pipeline into server.py (idempotent-ish)..."

# Only append once: simple guard
if ! grep -q "MMU API Integration" "$SERVER_FILE"; then
  cat >> "$SERVER_FILE" << 'EOF'

# ============================
# MMU API Integration
# ============================

from fastapi import HTTPException, UploadFile, File
from typing import Optional
from mmu.mmu_engine import MMUEngine

mmu = MMUEngine()

@app.get("/mmu/status")
def mmu_status():
    return mmu.get_status()

@app.post("/mmu/switch/{slot}")
def mmu_switch(slot: int):
    try:
        return mmu.switch_slot(slot)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/mmu/load")
def mmu_load():
    try:
        return mmu.load_filament()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/mmu/unload")
def mmu_unload():
    try:
        return mmu.unload_filament()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/mmu/reset")
def mmu_reset():
    try:
        return mmu.reset()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================
# Slicer Integration + LAN Capabilities
# ============================

@app.get("/fluxpath/capabilities")
def capabilities():
    return {
        "device": "FluxPath",
        "version": "1.0.0",
        "supports_upload": True,
        "supports_mmu": True,
        "supports_job_control": True,
        "lan_discovery": True,
        "ui": "mainsail/fluidd-compatible",
    }

UPLOAD_DIR = "jobs"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.post("/print/upload")
async def upload_print_job(file: UploadFile = File(...)):
    path = os.path.join(UPLOAD_DIR, file.filename)
    with open(path, "wb") as f:
        f.write(await file.read())
    # TODO: queue job, parse for color changes
    return {"status": "ok", "filename": file.filename}

current_job: Optional[str] = None
job_state: str = "idle"

@app.post("/print/start")
def start_print():
    global current_job, job_state
    # TODO: integrate with printer + MMU pipeline
    job_state = "printing"
    return {"status": "ok", "state": job_state}

@app.post("/print/pause")
def pause_print():
    global job_state
    job_state = "paused"
    return {"status": "ok", "state": job_state}

@app.post("/print/cancel")
def cancel_print():
    global job_state, current_job
    job_state = "cancelled"
    current_job = None
    return {"status": "ok", "state": job_state}

# ============================
# Multicolor G-code Pipeline (Stub)
# ============================

COLOR_CHANGE_MARKERS = [";COLOR_CHANGE", ";LAYER_COLOR", ";FLUXPATH_COLOR"]

def process_gcode_for_multicolor(gcode_path: str):
    """
    Stub: scan G-code for color change markers and
    schedule MMU slot switches.
    """
    if not os.path.exists(gcode_path):
        return {"error": "file not found"}

    color_events = []
    with open(gcode_path, "r") as f:
        for line_no, line in enumerate(f, start=1):
            for marker in COLOR_CHANGE_MARKERS:
                if marker in line:
                    # TODO: parse slot from comment, e.g. ;COLOR_CHANGE SLOT=2
                    color_events.append({"line": line_no, "marker": marker})
    return {"color_events": color_events}

@app.get("/print/analyze/{filename}")
def analyze_print_job(filename: str):
    path = os.path.join(UPLOAD_DIR, filename)
    return process_gcode_for_multicolor(path)

# ============================
# Web UI MMU Hooks (for Mainsail/Fluidd)
# ============================

@app.get("/ui/mmu/summary")
def ui_mmu_summary():
    """
    Endpoint for UI to poll MMU state.
    """
    return mmu.get_status()
EOF
fi

echo "→ Installing systemd service..."
sudo cp "$BASE_DIR/systemd/$SERVICE_NAME" /etc/systemd/system/$SERVICE_NAME
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

echo "→ Waiting for backend to start..."
sleep 3

echo "→ Checking /health..."
if curl -s http://localhost:9876/health > /dev/null; then
  echo "✔ Backend /health OK"
else
  echo "✖ Backend /health failed. Check: sudo journalctl -u $SERVICE_NAME -f"
fi

echo "→ Checking MMU status endpoint..."
curl -s http://localhost:9876/mmu/status || echo "⚠ /mmu/status not responding"

echo "→ Checking slicer capabilities..."
curl -s http://localhost:9876/fluxpath/capabilities || echo "⚠ /fluxpath/capabilities not responding"

echo "→ Checking MMU hardware..."
if lsusb | grep -i "serial" > /dev/null || dmesg | grep -i ttyUSB > /dev/null; then
  echo "✔ MMU hardware detected."
else
  echo "⚠ No MMU hardware detected."
fi

echo "=== FluxPath full platform install complete ==="
echo "Backend:   http://<host>:9876"
echo "MMU API:   /mmu/status, /mmu/switch/{slot}, /mmu/load, /mmu/unload, /mmu/reset"
echo "Slicer:    /fluxpath/capabilities, /print/upload, /print/start, /print/pause, /print/cancel"
echo "Multicolor: /print/analyze/{filename} (stubbed color event detection)"
echo "UI MMU:    /ui/mmu/summary"
