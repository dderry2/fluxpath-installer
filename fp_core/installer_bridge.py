import os
import subprocess
from pathlib import Path

from .config import FLUXPATH_ROOT
from .utils import log_info


def run_fluxpath_installer(config_dir: Path):
    installer = FLUXPATH_ROOT / "fluxpath_installer.sh"
    if not installer.exists():
        raise FileNotFoundError("FluxPath installer not found at {0}".format(installer))

    env = os.environ.copy()
    env["CONFIG_DIR"] = str(config_dir)

    log_info("Running installer with CONFIG_DIR={0}".format(config_dir))
    subprocess.run(["bash", str(installer)], check=True, env=env)
