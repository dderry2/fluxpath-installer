#!/bin/bash

echo "==============================================="
echo "   FluxPath Moonraker PolKit + Config Check"
echo "==============================================="

MOONRAKER_USER="$USER"
MOONRAKER_CFG_DIR="$HOME/printer_data/config"
MOONRAKER_CFG_MAIN="$MOONRAKER_CFG_DIR/moonraker.conf"
POLKIT_DIR="/etc/polkit-1/localauthority/50-local.d"
POLKIT_FILE="$POLKIT_DIR/moonraker.pkla"

# Track booleans
POLKIT_RULES_INSTALLED=false
MOONRAKER_CFG_FOUND=false
MOONRAKER_DEPRECATED_OPTIONS_FOUND=false
MOONRAKER_EXTENSIONS_BLOCK_FOUND=false

# ---------------------------------------------------------
# 1. Install PolKit rules for Moonraker
# ---------------------------------------------------------
echo ""
echo "--- PolKit Rules Installation ---"

if [ "$EUID" -ne 0 ]; then
  echo "NOTE: PolKit rule install requires sudo. Prompting..."
fi

sudo mkdir -p "$POLKIT_DIR"

sudo tee "$POLKIT_FILE" >/dev/null << EOF
[Allow Moonraker Service Management]
Identity=unix-user:$MOONRAKER_USER
Action=org.freedesktop.systemd1.manage-units
ResultActive=yes

[Allow Moonraker Package Management]
Identity=unix-user:$MOONRAKER_USER
Action=org.freedesktop.packagekit.system-sources-refresh;org.freedesktop.packagekit.package-install;org.freedesktop.packagekit.system-update
ResultActive=yes
EOF

if [ $? -eq 0 ]; then
  POLKIT_RULES_INSTALLED=true
fi

echo "POLKIT_RULES_INSTALLED=$POLKIT_RULES_INSTALLED"


# ---------------------------------------------------------
# 2. Moonraker config presence
# ---------------------------------------------------------
echo ""
echo "--- Moonraker Config Detection ---"

if [ -f "$MOONRAKER_CFG_MAIN" ]; then
  MOONRAKER_CFG_FOUND=true
  echo "MOONRAKER_CFG_FOUND=true"
else
  echo "MOONRAKER_CFG_FOUND=false"
fi


# ---------------------------------------------------------
# 3. Scan Moonraker config for deprecated / risky options
#    (2026 sanity: extensions, old options, etc.)
# ---------------------------------------------------------
echo ""
echo "--- Moonraker Config Compatibility Scan ---"

if [ "$MOONRAKER_CFG_FOUND" = true ]; then
  # Check for [extensions] block
  if grep -q "^

\[extensions\]

" "$MOONRAKER_CFG_MAIN"; then
    MOONRAKER_EXTENSIONS_BLOCK_FOUND=true
    MOONRAKER_DEPRECATED_OPTIONS_FOUND=true
    echo "DEPRECATED_EXTENSIONS_BLOCK=true"
  else
    echo "DEPRECATED_EXTENSIONS_BLOCK=false"
  fi

  # Check for specific deprecated options
  DEPRECATED_KEYS=(
    "enable_extensions"
    "extension_path"
  )

  for key in "${DEPRECATED_KEYS[@]}"; do
    if grep -q "$key" "$MOONRAKER_CFG_MAIN"; then
      echo "DEPRECATED_OPTION_$key=true"
      MOONRAKER_DEPRECATED_OPTIONS_FOUND=true
    else
      echo "DEPRECATED_OPTION_$key=false"
    fi
  done

else
  echo "SKIPPING_CONFIG_SCAN=true"
fi


# ---------------------------------------------------------
# 4. Suggest cleanup actions (non-destructive)
# ---------------------------------------------------------
echo ""
echo "--- Suggested Actions (Non-Destructive) ---"

if [ "$MOONRAKER_EXTENSIONS_BLOCK_FOUND" = true ]; then
  echo "SUGGEST_REMOVE_EXTENSIONS_BLOCK=true"
else
  echo "SUGGEST_REMOVE_EXTENSIONS_BLOCK=false"
fi

if [ "$MOONRAKER_DEPRECATED_OPTIONS_FOUND" = true ]; then
  echo "SUGGEST_REVIEW_DEPRECATED_OPTIONS=true"
else
  echo "SUGGEST_REVIEW_DEPRECATED_OPTIONS=false"
fi


# ---------------------------------------------------------
# 5. Final Summary
# ---------------------------------------------------------
echo ""
echo "==============================================="
echo "        FluxPath Moonraker Sanity Summary"
echo "==============================================="
echo "PolKit Rules Installed:     $POLKIT_RULES_INSTALLED"
echo "Moonraker Config Found:     $MOONRAKER_CFG_FOUND"
echo "Extensions Block Present:   $MOONRAKER_EXTENSIONS_BLOCK_FOUND"
echo "Deprecated Options Found:   $MOONRAKER_DEPRECATED_OPTIONS_FOUND"
echo "==============================================="
echo "If deprecated options are true, edit:"
echo "  $MOONRAKER_CFG_MAIN"
echo "and comment/remove [extensions], enable_extensions, extension_path."
echo "Then restart Moonraker:"
echo "  sudo systemctl restart moonraker"
echo "==============================================="
