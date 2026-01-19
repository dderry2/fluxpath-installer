#!/usr/bin/env bash
set -e

# --- CONFIG ---
USER_NAME="syko"
BASE_DIR="/home/${USER_NAME}/FluxPath"
VENV_DIR="${BASE_DIR}/venv"
SERVICE_NAME="fluxpath"
SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
PORT="9999"
# --------------

echo "==> Ensuring base structure..."
mkdir -p "${BASE_DIR}/fluxpath/core"
mkdir -p "${BASE_DIR}/scripts"

cd "$BASE_DIR"

# --- Ensure package init files ---
if [ ! -f "${BASE_DIR}/fluxpath/__init__.py" ]; then
  echo '__version__ = "0.1.0"' > "${BASE_DIR}/fluxpath/__init__.py"
fi

if [ ! -f "${BASE_DIR}/fluxpath/core/__init__.py" ]; then
  touch "${BASE_DIR}/fluxpath/core/__init__.py"
fi

# --- MMU logic module ---
cat << 'EOF_MMU' > "${BASE_DIR}/fluxpath/core/mmu.py"
from dataclasses import dataclass, asdict
from typing import Dict, List, Literal

ToolID = int

@dataclass
class Filament:
    tool: ToolID
    color_hex: str
    material: str
    name: str | None = None

@dataclass
class MMUCapabilities:
    tools: int
    purge_strategy: Literal["tower", "infill", "wipe", "none"]
    min_purge_volume: float
    max_purge_volume: float

@dataclass
class ToolchangePlan:
    sequence: List[ToolID]
    estimated_purge_volume: float
    warnings: List[str]

class MMUManager:
    def __init__(self) -> None:
        self._filaments: Dict[ToolID, Filament] = {}
        self._caps = MMUCapabilities(
            tools=4,
            purge_strategy="tower",
            min_purge_volume=80.0,
            max_purge_volume=300.0,
        )

    def get_capabilities(self) -> Dict:
        return asdict(self._caps)

    def set_filaments(self, filaments: List[Dict]) -> List[Dict]:
        self._filaments.clear()
        for f in filaments:
            tool = int(f["tool"])
            self._filaments[tool] = Filament(
                tool=tool,
                color_hex=f.get("color_hex", "#FFFFFF"),
                material=f.get("material", "PLA"),
                name=f.get("name"),
            )
        return [asdict(f) for f in self._filaments.values()]

    def get_filaments(self) -> List[Dict]:
        return [asdict(f) for f in self._filaments.values()]

    def plan_toolchanges(self, sequence: List[ToolID]) -> Dict:
        warnings: List[str] = []
        purge_per_change = 100.0
        estimated_purge = max(0.0, (len(sequence) - 1) * purge_per_change)

        if estimated_purge > self._caps.max_purge_volume:
            warnings.append(
                f"Estimated purge volume {estimated_purge} exceeds max {self._caps.max_purge_volume}"
            )

        return asdict(
            ToolchangePlan(
                sequence=sequence,
                estimated_purge_volume=estimated_purge,
                warnings=warnings,
            )
        )

mmu_manager = MMUManager()
EOF_MMU

# --- API wiring (extend api.py) ---
API_FILE="${BASE_DIR}/fluxpath/api.py"

if ! grep -q "from .core.mmu import mmu_manager" "$API_FILE" 2>/dev/null; then
  # Ensure imports and models are present
  cat << 'EOF_API_APPEND' >> "$API_FILE"

from pydantic import BaseModel
from typing import List
from .core.mmu import mmu_manager

class FilamentModel(BaseModel):
    tool: int
    color_hex: str
    material: str
    name: str | None = None

class ToolchangeRequest(BaseModel):
    sequence: List[int]

@app.get("/fluxpath/capabilities")
def get_capabilities():
    return {"result": "ok", "capabilities": mmu_manager.get_capabilities()}

@app.get("/fluxpath/filaments")
def get_filaments():
    return {"result": "ok", "filaments": mmu_manager.get_filaments()}

@app.post("/fluxpath/filaments")
def set_filaments(filaments: List[FilamentModel]):
    stored = mmu_manager.set_filaments([f.model_dump() for f in filaments])
    return {"result": "ok", "filaments": stored}

@app.post("/fluxpath/slicer/plan")
def slicer_plan(req: ToolchangeRequest):
    plan = mmu_manager.plan_toolchanges(req.sequence)
    return {"result": "ok", "plan": plan}
EOF_API_APPEND
fi

# --- Orca/Prusa post-processing script ---
cat << 'EOF_ORCA' > "${BASE_DIR}/scripts/fluxpath_orca_post.py"
#!/usr/bin/env python3
import json
import sys
from pathlib import Path

import requests

FLUXPATH_URL = "http://192.168.0.122:9999"

def main():
    if len(sys.argv) < 2:
        print("Usage: fluxpath_orca_post.py <gcode_file>", file=sys.stderr)
        sys.exit(1)

    gcode_path = Path(sys.argv[1])

    meta_path = gcode_path.with_suffix(".fluxpath.json")
    if not meta_path.exists():
        return

    with meta_path.open("r", encoding="utf-8") as f:
        meta = json.load(f)

    filaments = meta.get("filaments", [])
    sequence = meta.get("tool_sequence", [])

    try:
        requests.post(f"{FLUXPATH_URL}/fluxpath/filaments", json=filaments, timeout=5)
        requests.post(f"{FLUXPATH_URL}/fluxpath/slicer/plan", json={"sequence": sequence}, timeout=5)
    except Exception as e:
        print(f"[FluxPath] Failed to contact backend: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
EOF_ORCA
chmod +x "${BASE_DIR}/scripts/fluxpath_orca_post.py"

cat << 'EOF_PRUSA' > "${BASE_DIR}/scripts/fluxpath_prusa_post.sh"
#!/usr/bin/env bash
python3 /home/syko/FluxPath/scripts/fluxpath_orca_post.py "$1"
EOF_PRUSA
chmod +x "${BASE_DIR}/scripts/fluxpath_prusa_post.sh"

# --- CLI tool ---
cat << 'EOF_CLI' > "${BASE_DIR}/scripts/fluxpath_cli.py"
#!/usr/bin/env python3
import argparse
import json

import requests

FLUXPATH_URL = "http://127.0.0.1:9999"

def cmd_version(args):
    r = requests.get(f"{FLUXPATH_URL}/fluxpath/version", timeout=5)
    print(json.dumps(r.json(), indent=2))

def cmd_caps(args):
    r = requests.get(f"{FLUXPATH_URL}/fluxpath/capabilities", timeout=5)
    print(json.dumps(r.json(), indent=2))

def cmd_diag(args):
    r = requests.get(f"{FLUXPATH_URL}/fluxpath/diagnostics", timeout=5)
    print(json.dumps(r.json(), indent=2))

def main():
    p = argparse.ArgumentParser(prog="fluxpath")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("version").set_defaults(func=cmd_version)
    sub.add_parser("caps").set_defaults(func=cmd_caps)
    sub.add_parser("diag").set_defaults(func=cmd_diag)

    args = p.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()
EOF_CLI
chmod +x "${BASE_DIR}/scripts/fluxpath_cli.py"

# --- Updater script ---
cat << 'EOF_UPDATE' > "${BASE_DIR}/scripts/fluxpath_updater.sh"
#!/usr/bin/env bash
set -e

USER_NAME="syko"
BASE_DIR="/home/${USER_NAME}/FluxPath"

cd "$BASE_DIR"

if [ ! -d .git ]; then
  echo "No git repo here; updater expects FluxPath to be a git clone."
  exit 1
fi

echo "==> Fetching latest..."
git fetch origin
git pull --ff-only origin main || git pull --ff-only origin master || true

echo "==> Re-running backend installer..."
./install_fluxpath_backend.sh

echo "==> Restarting service..."
sudo systemctl restart fluxpath

echo "FluxPath updated."
EOF_UPDATE
chmod +x "${BASE_DIR}/scripts/fluxpath_updater.sh"

# --- GitHub release packaging ---
cat << 'EOF_PYPROJECT' > "${BASE_DIR}/pyproject.toml"
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "fluxpath"
version = "0.1.0"
description = "FluxPath MMU intelligence backend"
authors = [{ name = "Sy" }]
requires-python = ">=3.10"
dependencies = [
    "fastapi",
    "uvicorn[standard]",
    "requests",
]
EOF_PYPROJECT

cat << 'EOF_BUILD' > "${BASE_DIR}/scripts/fluxpath_build_release.sh"
#!/usr/bin/env bash
set -e

cd /home/syko/FluxPath

python3 -m pip install --upgrade build
python3 -m build

echo "Dist artifacts in ./dist/"
EOF_BUILD
chmod +x "${BASE_DIR}/scripts/fluxpath_build_release.sh"

# --- Ensure venv + deps (including requests) ---
echo "==> Ensuring venv and Python deps..."
if [ ! -d "$VENV_DIR" ]; then
  /usr/bin/python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install fastapi uvicorn[standard] requests

# --- Systemd service (if not already correct) ---
echo "==> Writing systemd service..."
cat << EOF_UNIT | sudo tee "$SYSTEMD_UNIT" > /dev/null
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
EOF_UNIT

echo "==> Reloading systemd and restarting service..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo ""
echo "=============================================="
echo " FluxPath full stack installed:"
echo "  - MMU API endpoints"
echo "  - Orca/Prusa post-processing hooks"
echo "  - CLI: scripts/fluxpath_cli.py"
echo "  - Updater: scripts/fluxpath_updater.sh"
echo "  - Build: scripts/fluxpath_build_release.sh"
echo ""
echo " Test API:"
echo "   curl -s http://192.168.0.122:${PORT}/fluxpath/capabilities"
echo "=============================================="
