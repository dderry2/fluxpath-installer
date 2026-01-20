#!/bin/bash

echo "=== FluxPath MMU Config Writer ==="

CONFIG_DIR="$HOME/FluxPath/config"
CONFIG_FILE="$CONFIG_DIR/fluxpath_config.json"

# Ensure directory exists
mkdir -p "$CONFIG_DIR"

echo "Writing FluxPath MMU config to:"
echo "  $CONFIG_FILE"
echo ""

cat << 'EOF' > "$CONFIG_FILE"
{
  "drive_motors": 2,
  "motor_pins": [
    "mmu:PB14",
    "mmu:PB11"
  ],
  "sensor_pins": [
    "mmu:PB7",
    "mmu:PB8",
    "mmu:PB9"
  ],
  "colors": "red, blue",
  "cutter_present": true,
  "cutter_pin": "PA1",
  "feed_distance_mm": 60,
  "retract_distance_mm": 60
}
EOF

echo "Config written successfully."
echo ""

# Restart backend
echo "Restarting FluxPath backend service..."
sudo systemctl restart fluxpath.service

echo ""
echo "Done. Test with:"
echo "  curl -s http://localhost:9876/mmu/status"
echo "==========================================="
