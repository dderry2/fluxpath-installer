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
