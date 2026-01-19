import json
from dataclasses import dataclass, asdict
from typing import List, Optional

from .config import INSTANCES_REGISTRY, KLIPPER_PORT_BASE, MOONRAKER_PORT_BASE


@dataclass
class Instance:
    id: int
    name: str
    config_dir: str
    klipper_dir: str
    service_name: str
    klipper_port: int
    moonraker_port: int
    moonraker_service: Optional[str] = None
    active: bool = False
    sandbox: bool = False


def load_instances() -> List[Instance]:
    if not INSTANCES_REGISTRY.exists():
        return []
    data = json.loads(INSTANCES_REGISTRY.read_text())
    return [Instance(**item) for item in data]


def save_instances(instances: List[Instance]) -> None:
    INSTANCES_REGISTRY.parent.mkdir(parents=True, exist_ok=True)
    INSTANCES_REGISTRY.write_text(
        json.dumps([asdict(i) for i in instances], indent=2)
    )


def next_id(instances: List[Instance]) -> int:
    if not instances:
        return 1
    return max(i.id for i in instances) + 1


def allocate_ports(
    instances: List[Instance],
    base_klipper: int = KLIPPER_PORT_BASE,
    base_moonraker: int = MOONRAKER_PORT_BASE,
) -> (int, int):
    used_k = {i.klipper_port for i in instances}
    used_m = {i.moonraker_port for i in instances}

    k = base_klipper
    m = base_moonraker

    # step by 10 to keep ranges visually grouped
    while k in used_k:
        k += 10
    while m in used_m:
        m += 10

    return k, m
