#!/bin/bash
set -e

BASE_DIR="/home/$USER/FluxPath"
SERVER_FILE="$BASE_DIR/server.py"

echo "=== Enabling MMU API + Slicer Integration ==="

if [ ! -f "$SERVER_FILE" ]; then
    echo "✖ server.py not found. Are you sure FluxPath is installed?"
    exit 1
fi

echo "→ Injecting MMU API endpoints into server.py..."

cat >> "$SERVER_FILE" << 'EOF'

# ============================
# MMU API Integration
# ============================

from fastapi import HTTPException
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
    return mmu.load_filament()

@app.post("/mmu/unload")
def mmu_unload():
    return mmu.unload_filament()

@app.post("/mmu/reset")
def mmu_reset():
    return mmu.reset()

# ============================
# Slicer Integration
# ============================

@app.get("/fluxpath/capabilities")
def capabilities():
    return {
        "device": "FluxPath",
        "version": "1.0",
        "supports_upload": True,
        "supports_mmu": True,
        "supports_job_control": True,
    }

@app.post("/print/upload")
def upload_print_job():
    return {"status": "ok", "message": "Job uploaded (stub)"}

@app.post("/print/start")
def start_print():
    return {"status": "ok", "message": "Print started (stub)"}

@app.post("/print/pause")
def pause_print():
    return {"status": "ok", "message": "Print paused (stub)"}

@app.post("/print/cancel")
def cancel_print():
    return {"status": "ok", "message": "Print cancelled (stub)"}

EOF

echo "→ Restarting backend..."
sudo systemctl restart fluxpath.service

echo "→ Verifying MMU endpoint..."
curl -s http://localhost:9876/mmu/status || echo "⚠ MMU status endpoint not responding."

echo "→ Verifying slicer capabilities..."
curl -s http://localhost:9876/fluxpath/capabilities || echo "⚠ Capabilities endpoint not responding."

echo "=== MMU + Slicer integration enabled ==="
