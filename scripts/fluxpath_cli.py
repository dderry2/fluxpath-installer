#!/usr/bin/env python3
import argparse
import json

import requests

FLUXPATH_URL = "http://127.0.0.1:9999"

def cmd_version(args):
    r = requests.get(f"{FLUXPATH_URL}/fluxpath/version", timeout=5)
    print(json.dumps(r.json(), indent=2))

def cmd_caps(args):
    r = requests.get(f"{FLUXPATH_URL}/fluxpath/capabilities", timeout=5)
    print(json.dumps(r.json(), indent=2))

def cmd_diag(args):
    r = requests.get(f"{FLUXPATH_URL}/fluxpath/diagnostics", timeout=5)
    print(json.dumps(r.json(), indent=2))

def main():
    p = argparse.ArgumentParser(prog="fluxpath")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("version").set_defaults(func=cmd_version)
    sub.add_parser("caps").set_defaults(func=cmd_caps)
    sub.add_parser("diag").set_defaults(func=cmd_diag)

    args = p.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()
