#!/bin/bash
set -e

echo ""
echo "======================================================"
echo " FluxPath Backend Installer"
echo "======================================================"
echo ""

# -------------------------------------------------------
# 1. Detect home directory (your chosen logic)
# -------------------------------------------------------
detect_home() {
  local current_user home_current home_pi choice

  current_user="$(whoami)"
  home_current="/home/$current_user"
  home_pi="/home/pi"

  # Prefer $HOME if valid
  if [ -d "$HOME" ]; then
    home_current="$HOME"
  fi

  if [ -d "$home_current" ] && [ -d "$home_pi" ] && [ "$home_current" != "$home_pi" ]; then
    echo "Multiple home directories detected:"
    echo "  1) $home_current (current user: $current_user)"
    echo "  2) $home_pi (user: pi)"
    echo ""
    while true; do
      read -rp "Which should FluxPath use? [1/2]: " choice
      case "$choice" in
        1)
          FLUXPATH_HOME="$home_current"
          break
          ;;
        2)
          if [ "$current_user" != "pi" ]; then
            echo ""
            echo "WARNING: You selected /home/pi but you are '$current_user'."
            echo "Writing into /home/pi may require sudo permissions."
            read -rp "Continue with /home/pi anyway? [y/N]: " yn
            case "$yn" in
              [Yy]*)
                FLUXPATH_HOME="$home_pi"
                break
                ;;
              *)
                echo "Aborting. Re-run installer and choose option 1."
                exit 1
                ;;
            esac
          else
            FLUXPATH_HOME="$home_pi"
            break
          fi
          ;;
        *)
          echo "Please enter 1 or 2."
          ;;
      esac
    done
  elif [ -d "$home_current" ]; then
    FLUXPATH_HOME="$home_current"
  elif [ -d "$home_pi" ]; then
    FLUXPATH_HOME="$home_pi"
  else
    echo "Could not find a suitable home directory. Falling back to \$HOME=$HOME"
    FLUXPATH_HOME="$HOME"
  fi

  echo "Using FluxPath home: $FLUXPATH_HOME"
}

detect_home

BASE_DIR="$FLUXPATH_HOME/FluxPath"
BACKEND_DIR="$BASE_DIR/backend"
MMU_DIR="$BACKEND_DIR/mmu"
CONFIG_PATH="$BASE_DIR/config/fluxpath_config.json"

mkdir -p "$MMU_DIR"

echo ""
echo "Installing backend files into:"
echo "  $MMU_DIR"
echo ""

# -------------------------------------------------------
# 2. Write model.py
# -------------------------------------------------------
cat << 'EOF' > "$MMU_DIR/model.py"
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel
import time

class MMUState(str, Enum):
    IDLE = "idle"
    LOADING = "loading"
    UNLOADING = "unloading"
    TOOLCHANGE = "toolchange"
    ERROR = "error"
    RECOVERING = "recovering"

class Slot(BaseModel):
    index: int
    color: str
    has_filament: bool = False

class MMUStatus(BaseModel):
    state: MMUState
    active_slot: Optional[int] = None
    last_error: Optional[str] = None
    slots: List[Slot]
    simulation: bool = True
    updated_at: float

class MMUConfig(BaseModel):
    drive_motors: int
    motor_pins: List[str]
    sensor_pins: List[str]
    colors: List[str]
    cutter_present: bool
    cutter_pin: Optional[str]
    feed_distance_mm: float
    retract_distance_mm: float
EOF

# -------------------------------------------------------
# 3. Write controller.py
# -------------------------------------------------------
cat << 'EOF' > "$MMU_DIR/controller.py"
from typing import Optional, List, Callable
from .model import MMUStatus, MMUState, Slot, MMUConfig
import time
import threading

class MMUController:
    def __init__(self, config: MMUConfig):
        self._lock = threading.Lock()
        self.config = config
        self._broadcast: Optional[Callable[[str, dict], None]] = None
        self.status = MMUStatus(
            state=MMUState.IDLE,
            active_slot=None,
            last_error=None,
            slots=[
                Slot(index=i, color=config.colors[i] if i < len(config.colors) else f"Slot {i+1}")
                for i in range(config.drive_motors)
            ],
            simulation=True,
            updated_at=time.time(),
        )

    def set_broadcaster(self, fn: Callable[[str, dict], None]) -> None:
        self._broadcast = fn

    def _update(self, **kwargs) -> None:
        for k, v in kwargs.items():
            setattr(self.status, k, v)
        self.status.updated_at = time.time()
        if self._broadcast:
            try:
                self._broadcast("mmu_status", self.status.dict())
            except Exception:
                pass

    def get_status(self) -> MMUStatus:
        with self._lock:
            return self.status.copy()

    def simulate_load_slot(self, slot_index: int) -> None:
        with self._lock:
            if slot_index < 0 or slot_index >= len(self.status.slots):
                self._update(state=MMUState.ERROR, last_error=f"Invalid slot {slot_index}")
                return
            self._update(state=MMUState.LOADING, active_slot=slot_index)
        time.sleep(0.3)
        with self._lock:
            for s in self.status.slots:
                if s.index == slot_index:
                    s.has_filament = True
            self._update(state=MMUState.IDLE)

    def simulate_unload(self) -> None:
        with self._lock:
            if self.status.active_slot is None:
                self._update(state=MMUState.ERROR, last_error="No active slot to unload")
                return
            slot_index = self.status.active_slot
            self._update(state=MMUState.UNLOADING)
        time.sleep(0.3)
        with self._lock:
            for s in self.status.slots:
                if s.index == slot_index:
                    s.has_filament = False
            self._update(state=MMUState.IDLE, active_slot=None)

    def simulate_toolchange(self, slot_index: int) -> None:
        self.simulate_unload()
        self.simulate_load_slot(slot_index)

    def simulate_recover(self) -> None:
        with self._lock:
            self._update(state=MMUState.RECOVERING, last_error=None)
        time.sleep(0.2)
        with self._lock:
            self._update(state=MMUState.IDLE)
EOF

# -------------------------------------------------------
# 4. Write routes.py
# -------------------------------------------------------
cat << 'EOF' > "$MMU_DIR/routes.py"
from fastapi import APIRouter, HTTPException, Depends
from typing import List
from pathlib import Path
import json
from pydantic import BaseModel

from .model import MMUStatus, MMUConfig
from .controller import MMUController

router = APIRouter()

CONFIG_PATH = Path.home() / "FluxPath" / "config" / "fluxpath_config.json"
_mmu_controller: MMUController | None = None

def load_config() -> MMUConfig:
    if not CONFIG_PATH.exists():
        raise RuntimeError(f"FluxPath config not found at {CONFIG_PATH}")
    data = json.loads(CONFIG_PATH.read_text())
    return MMUConfig(
        drive_motors=data["drive_motors"],
        motor_pins=data["motor_pins"],
        sensor_pins=data["sensor_pins"],
        colors=[c.strip() for c in data["colors"].split(",")],
        cutter_present=data["cutter_present"],
        cutter_pin=data.get("cutter_pin"),
        feed_distance_mm=float(data["feed_distance_mm"]),
        retract_distance_mm=float(data["retract_distance_mm"]),
    )

def get_mmu() -> MMUController:
    global _mmu_controller
    if _mmu_controller is None:
        _mmu_controller = MMUController(load_config())
    return _mmu_controller

@router.get("/mmu/status", response_model=MMUStatus)
def mmu_status(mmu: MMUController = Depends(get_mmu)):
    return mmu.get_status()

@router.post("/mmu/load_slot/{slot}")
def mmu_load_slot(slot: int, mmu: MMUController = Depends(get_mmu)):
    mmu.simulate_load_slot(slot)
    st = mmu.get_status()
    if st.state == "error":
        raise HTTPException(status_code=400, detail=st.last_error)
    return st

@router.post("/mmu/unload")
def mmu_unload(mmu: MMUController = Depends(get_mmu)):
    mmu.simulate_unload()
    st = mmu.get_status()
    if st.state == "error":
        raise HTTPException(status_code=400, detail=st.last_error)
    return st

@router.post("/mmu/tool/{slot}")
def mmu_tool(slot: int, mmu: MMUController = Depends(get_mmu)):
    mmu.simulate_toolchange(slot)
    st = mmu.get_status()
    if st.state == "error":
        raise HTTPException(status_code=400, detail=st.last_error)
    return st

@router.post("/mmu/recover")
def mmu_recover(mmu: MMUController = Depends(get_mmu)):
    mmu.simulate_recover()
    return mmu.get_status()

class MotorInfo(BaseModel):
    index: int
    pin: str

class SensorInfo(BaseModel):
    index: int
    pin: str
    triggered: bool

@router.get("/motors", response_model=List[MotorInfo])
def motors(mmu: MMUController = Depends(get_mmu)):
    cfg = mmu.config
    return [
        MotorInfo(index=i, pin=cfg.motor_pins[i])
        for i in range(cfg.drive_motors)
    ]

@router.get("/sensors", response_model=List[SensorInfo])
def sensors(mmu: MMUController = Depends(get_mmu)):
    cfg = mmu.config
    st = mmu.get_status()
    return [
        SensorInfo(
            index=i,
            pin=cfg.sensor_pins[i],
            triggered=st.slots[i].has_filament,
        )
        for i in range(cfg.drive_motors)
    ]
EOF

# -------------------------------------------------------
# 5. Patch main.py
# -------------------------------------------------------
MAIN_PY="$BACKEND_DIR/main.py"

if [ -f "$MAIN_PY" ]; then
  echo ""
  echo "Patching $MAIN_PY..."
  python3 - << EOF
from pathlib import Path

main = Path("$MAIN_PY")
text = main.read_text()

if "mmu_routes" not in text:
    text = text.replace(
        "from fastapi import FastAPI",
        "from fastapi import FastAPI\nfrom backend.mmu import routes as mmu_routes"
    )

if "app.include_router(mmu_routes.router)" not in text:
    text = text.replace(
        "app = FastAPI()",
        "app = FastAPI()\napp.include_router(mmu_routes.router)"
    )

main.write_text(text)
EOF
else
  echo ""
  echo "WARNING: $MAIN_PY not found. You must manually import:"
  echo "  from backend.mmu import routes as mmu_routes"
  echo "  app.include_router(mmu_routes.router)"
fi

echo ""
echo "======================================================"
echo " FluxPath Backend Installed Successfully"
echo "======================================================"
echo ""
echo "Backend directory:"
echo "  $BACKEND_DIR"
echo ""
echo "MMU files created:"
echo "  $MMU_DIR/model.py"
echo "  $MMU_DIR/controller.py"
echo "  $MMU_DIR/routes.py"
echo ""
echo "Restart your backend service to activate the MMU:"
echo "  sudo systemctl restart fluxpath.service"
echo ""
echo "You're ready for slicer‑agnostic toolchanges."
echo ""

