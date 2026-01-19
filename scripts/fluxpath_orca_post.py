#!/usr/bin/env python3
import json
import sys
from pathlib import Path

import requests

FLUXPATH_URL = "http://192.168.0.122:9999"

def main():
    if len(sys.argv) < 2:
        print("Usage: fluxpath_orca_post.py <gcode_file>", file=sys.stderr)
        sys.exit(1)

    gcode_path = Path(sys.argv[1])

    meta_path = gcode_path.with_suffix(".fluxpath.json")
    if not meta_path.exists():
        return

    with meta_path.open("r", encoding="utf-8") as f:
        meta = json.load(f)

    filaments = meta.get("filaments", [])
    sequence = meta.get("tool_sequence", [])

    try:
        requests.post(f"{FLUXPATH_URL}/fluxpath/filaments", json=filaments, timeout=5)
        requests.post(f"{FLUXPATH_URL}/fluxpath/slicer/plan", json={"sequence": sequence}, timeout=5)
    except Exception as e:
        print(f"[FluxPath] Failed to contact backend: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
