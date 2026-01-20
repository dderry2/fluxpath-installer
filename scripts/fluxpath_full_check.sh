#!/bin/bash

echo "==============================================="
echo "      FluxPath Full System Boolean Check"
echo "==============================================="

# ---------------------------------------------------------
# 1. Install Fluidd Panel
# ---------------------------------------------------------
echo ""
echo "--- Fluidd Panel Installation ---"

PANEL_SRC="$HOME/FluxPath/ui/fluxpath_panel.json"
PANEL_DST="$HOME/printer_data/config/fluidd/panels/fluxpath_panel.json"

mkdir -p "$HOME/printer_data/config/fluidd/panels"

if [ -f "$PANEL_SRC" ]; then
    cp "$PANEL_SRC" "$PANEL_DST"
    echo "FLUIDD_PANEL_INSTALLED=true"
else
    echo "FLUIDD_PANEL_INSTALLED=false"
fi


# ---------------------------------------------------------
# 2. Auto‑detect webcam
# ---------------------------------------------------------
echo ""
echo "--- Webcam Auto‑Detection ---"

WEBCAM_CFG="$HOME/printer_data/config/fluidd.cfg"

# Detect /dev/video* devices
VIDEO_DEV=$(ls /dev/video* 2>/dev/null | head -n 1)

if [ -n "$VIDEO_DEV" ]; then
    echo "WEBCAM_DETECTED=true"
else
    echo "WEBCAM_DETECTED=false"
fi

# Configure Fluidd webcam entry
if [ -n "$VIDEO_DEV" ]; then
    # Ensure config file exists
    touch "$WEBCAM_CFG"

    # Remove old webcam entries
    sed -i '/webcams:/,$d' "$WEBCAM_CFG"

    cat << EOF >> "$WEBCAM_CFG"
webcams:
  - name: FluxCam
    url: http://$(hostname -I | awk '{print $1}'):8080/?action=stream
    service: mjpgstreamer
EOF

    echo "WEBCAM_CONFIGURED=true"
else
    echo "WEBCAM_CONFIGURED=false"
fi


# ---------------------------------------------------------
# 3. Validate FluxPath Backend
# ---------------------------------------------------------
echo ""
echo "--- FluxPath Backend Validation ---"

# Check service running
if systemctl is-active --quiet fluxpath.service; then
    echo "SERVICE_RUNNING=true"
else
    echo "SERVICE_RUNNING=false"
fi

# Check MMU router mounted
if curl -s http://localhost:9876/openapi.json | grep -q "/mmu/status"; then
    echo "MMU_ROUTER_MOUNTED=true"
else
    echo "MMU_ROUTER_MOUNTED=false"
fi

# Check config exists
CONFIG="$HOME/FluxPath/config/fluxpath_config.json"
if [ -f "$CONFIG" ]; then
    echo "CONFIG_EXISTS=true"
else
    echo "CONFIG_EXISTS=false"
fi

# Required keys
REQUIRED_KEYS=("drive_motors" "motor_pins" "sensor_pins" "colors" "feed_distance_mm" "retract_distance_mm")

for key in "${REQUIRED_KEYS[@]}"; do
    if grep -q "\"$key\"" "$CONFIG" 2>/dev/null; then
        echo "CONFIG_KEY_$key=true"
    else
        echo "CONFIG_KEY_$key=false"
    fi
done

# Test MMU status endpoint
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9876/mmu/status)
if [ "$STATUS" = "200" ]; then
    echo "MMU_STATUS_ENDPOINT=true"
else
    echo "MMU_STATUS_ENDPOINT=false"
fi


# ---------------------------------------------------------
# 4. Validate Webcam Stream
# ---------------------------------------------------------
echo ""
echo "--- Webcam Stream Validation ---"

STREAM_URL="http://$(hostname -I | awk '{print $1}'):8080/?action=stream"
STREAM_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$STREAM_URL")

if [ "$STREAM_CODE" = "200" ] || [ "$STREAM_CODE" = "302" ]; then
    echo "WEBCAM_STREAM_ACTIVE=true"
else
    echo "WEBCAM_STREAM_ACTIVE=false"
fi


# ---------------------------------------------------------
# 5. Final Summary
# ---------------------------------------------------------
echo ""
echo "==============================================="
echo "         FluxPath Full System Summary"
echo "==============================================="
echo "Panel Installed:        $(grep FLUIDD_PANEL_INSTALLED=true <<< $(cat))"
echo "Webcam Detected:        $(grep WEBCAM_DETECTED=true <<< $(cat))"
echo "Webcam Configured:      $(grep WEBCAM_CONFIGURED=true <<< $(cat))"
echo "Backend Running:        $(grep SERVICE_RUNNING=true <<< $(cat))"
echo "MMU Router Mounted:     $(grep MMU_ROUTER_MOUNTED=true <<< $(cat))"
echo "MMU Status Endpoint:    $(grep MMU_STATUS_ENDPOINT=true <<< $(cat))"
echo "Webcam Stream Active:   $(grep WEBCAM_STREAM_ACTIVE=true <<< $(cat))"
echo "==============================================="
