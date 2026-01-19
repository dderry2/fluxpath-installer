# /home/syko/FluxPath/fluxpath/core/instances.py

from dataclasses import dataclass, asdict
from typing import Dict, List
import uuid
import threading

@dataclass
class Instance:
    id: str
    name: str
    status: str

class InstanceManager:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._instances: Dict[str, Instance] = {}

    def list_instances(self) -> List[Dict]:
        with self._lock:
            return [asdict(i) for i in self._instances.values()]

    def create_instance(self, name: str) -> Dict:
        with self._lock:
            inst_id = str(uuid.uuid4())
            inst = Instance(id=inst_id, name=name, status="idle")
            self._instances[inst_id] = inst
            return asdict(inst)

    def get_instance(self, inst_id: str) -> Dict | None:
        with self._lock:
            inst = self._instances.get(inst_id)
            return asdict(inst) if inst else None

    def set_status(self, inst_id: str, status: str) -> Dict | None:
        with self._lock:
            inst = self._instances.get(inst_id)
            if not inst:
                return None
            inst.status = status
            return asdict(inst)

instance_manager = InstanceManager()
