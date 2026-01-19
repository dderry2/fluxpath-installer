#!/usr/bin/env bash
set -e

USER_NAME="syko"
BASE_DIR="/home/${USER_NAME}/FluxPath"
PANEL_SRC="${BASE_DIR}/fluidd/fluxpath_panel.json"
PANEL_DIR="/home/${USER_NAME}/printer_data/config/fluidd/custom_panels"
PANEL_DEST="${PANEL_DIR}/fluxpath_panel.json"

if [ ! -f "$PANEL_SRC" ]; then
  echo "Panel JSON not found at ${PANEL_SRC}"
  exit 1
fi

mkdir -p "$PANEL_DIR"
cp "$PANEL_SRC" "$PANEL_DEST"

echo "FluxPath Fluidd panel installed to ${PANEL_DEST}."
echo "Reload Fluidd UI to see the panel."
