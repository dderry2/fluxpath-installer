#!/usr/bin/env bash
set -e

cd /home/syko/FluxPath

python3 -m pip install --upgrade build
python3 -m build

echo "Dist artifacts in ./dist/"
