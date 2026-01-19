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
