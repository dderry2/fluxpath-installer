from pathlib import Path

from .config import INSTANCE_DATA_BASE, KLIPPER_TEMPLATE, HOME
from .utils import log_info, run_cmd


def create_instance_dirs(instance_id: int) -> Path:
    root = INSTANCE_DATA_BASE / "instance_{0}".format(instance_id)
    (root / "config").mkdir(parents=True, exist_ok=True)
    (root / "logs").mkdir(parents=True, exist_ok=True)
    (root / "comms").mkdir(parents=True, exist_ok=True)
    log_info("Created instance dirs at {0}".format(root))
    return root


def clone_klipper(instance_id: int) -> Path:
    target = HOME / "klipper_{0}".format(instance_id)
    if target.exists():
        log_info("Klipper clone already exists at {0}".format(target))
        return target
    run_cmd(["git", "clone", str(KLIPPER_TEMPLATE), str(target)])
    return target


def write_base_printer_cfg(config_dir: Path):
    cfg = config_dir / "printer.cfg"
    if cfg.exists():
        return
    cfg.write_text(
        "# FluxPath instance base config\n"
        "[include mmu/mmu_main.cfg]\n"
    )
    log_info("Wrote base printer.cfg at {0}".format(cfg))

def write_mmu_steppers_cfg(config_dir: Path):
    mmu_dir = config_dir / "mmu"
    mmu_dir.mkdir(exist_ok=True)

    steppers = mmu_dir / "mmu_steppers.cfg"
    if steppers.exists():
        return

    steppers.write_text(
        "# ============================================\n"
        "# MMU steppers ON SKR MINI E3 (MCU: mmu)\n"
        "# ============================================\n\n"
        "# Tool 0 -> extruder1\n"
        "# Tool 1 -> extruder2\n\n"
        "[extruder_stepper extruder1]\n"
        "step_pin: mmu:PB13\n"
        "dir_pin: mmu:PB12\n"
        "enable_pin: !mmu:PB14\n"
        "rotation_distance: 7.71\n"
        "microsteps: 16\n"
        "full_steps_per_rotation: 200\n"
        "extruder: extruder\n\n"
        "[tmc2209 extruder_stepper extruder1]\n"
        "uart_pin: mmu:PB15\n"
        "run_current: 0.8\n"
        "hold_current: 0.5\n"
        "stealthchop_threshold: 0\n\n"
        "[extruder_stepper extruder2]\n"
        "step_pin: mmu:PB10\n"
        "dir_pin: mmu:PB2\n"
        "enable_pin: !mmu:PB11\n"
        "rotation_distance: 7.71\n"
        "microsteps: 16\n"
        "full_steps_per_rotation: 200\n"
        "extruder: extruder\n\n"
        "[tmc2209 extruder_stepper extruder2]\n"
        "uart_pin: mmu:PC6\n"
        "run_current: 0.8\n"
        "hold_current: 0.5\n"
        "stealthchop_threshold: 0\n"
    )

    log_info("Wrote mmu_steppers.cfg at {0}".format(steppers))

