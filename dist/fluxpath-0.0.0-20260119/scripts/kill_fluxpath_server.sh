#!/bin/bash

echo "Stopping any running FluxPath legacy server..."

# Kill anything using port 9876
sudo fuser -k 9876/tcp 2>/dev/null

# Kill any python process running the old module
pkill -f "fluxpath.device.server"

echo "Renaming legacy server module to disable auto-start..."
LEGACY_PATH="$HOME/FluxPath/fluxpath/device/server.py"
if [ -f "$LEGACY_PATH" ]; then
    mv "$LEGACY_PATH" "$LEGACY_PATH.disabled"
    echo "Renamed server.py → server.py.disabled"
fi

# Also disable __pycache__ so Python can't load compiled version
CACHE_PATH="$HOME/FluxPath/fluxpath/device/__pycache__"
if [ -d "$CACHE_PATH" ]; then
    rm -rf "$CACHE_PATH"
    echo "Removed __pycache__"
fi

echo "Verifying port 9876 is free..."
sudo ss -tulpn | grep 9876 || echo "Port 9876 is now free."

echo "Done."
