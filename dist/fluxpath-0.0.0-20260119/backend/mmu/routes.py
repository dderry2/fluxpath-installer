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
