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
