# /home/syko/FluxPath/fluxpath/core/diagnostics.py

import socket
from typing import Dict

def basic_diagnostics() -> Dict:
    return {
        "hostname": socket.gethostname(),
        "status": "ok",
    }
