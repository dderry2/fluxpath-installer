#!/bin/bash

echo "=== FluxPath Legacy Server Removal ==="

echo "Stopping any running legacy server on port 9876..."
sudo fuser -k 9876/tcp 2>/dev/null

echo "Killing any python process running fluxpath.device.server..."
pkill -f "fluxpath.device.server"

echo "Disabling legacy server module..."
LEGACY_FILE="$HOME/FluxPath/fluxpath/device/server.py"
if [ -f "$LEGACY_FILE" ]; then
    mv "$LEGACY_FILE" "$LEGACY_FILE.disabled"
    echo "Renamed server.py → server.py.disabled"
else
    echo "Legacy server.py not found (already removed or renamed)."
fi

echo "Removing __pycache__ to prevent Python from loading cached modules..."
CACHE_DIR="$HOME/FluxPath/fluxpath/device/__pycache__"
if [ -d "$CACHE_DIR" ]; then
    rm -rf "$CACHE_DIR"
    echo "Removed __pycache__"
else
    echo "No __pycache__ directory found."
fi

echo "Verifying port 9876 is free..."
if sudo ss -tulpn | grep 9876 > /dev/null; then
    echo "ERROR: Port 9876 is STILL in use."
    echo "Process details:"
    sudo ss -tulpn | grep 9876
else
    echo "SUCCESS: Port 9876 is now free."
fi

echo "=== Done. Legacy server disabled permanently. ==="
