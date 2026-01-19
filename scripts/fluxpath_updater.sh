#!/usr/bin/env bash
set -e

USER_NAME="syko"
BASE_DIR="/home/${USER_NAME}/FluxPath"

cd "$BASE_DIR"

if [ ! -d .git ]; then
  echo "No git repo here; updater expects FluxPath to be a git clone."
  exit 1
fi

echo "==> Fetching latest..."
git fetch origin
git pull --ff-only origin main || git pull --ff-only origin master || true

echo "==> Re-running backend installer..."
./install_fluxpath_all_in_one.sh

echo "==> Restarting service..."
sudo systemctl restart fluxpath

echo "FluxPath updated."
