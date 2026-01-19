#!/usr/bin/env bash
#
# FluxPath Installer Bundle Builder
# Creates fluxpath-installer-v0.1.0.zip
#

set -euo pipefail

PROJECT_DIR="$HOME/fluxpath-installer"
ZIP_NAME="fluxpath-installer-v0.1.0.zip"

echo "──────────────────────────────────────────────"
echo " FluxPath Installer • Bundle Builder"
echo "──────────────────────────────────────────────"
echo
echo "Project directory: ${PROJECT_DIR}"
echo "Output archive:    ${ZIP_NAME}"
echo

# Validate required files exist
required_files=(
  "fluxpath-install.sh"
  "fluxpath-installer.sh"
  "fluxpath-precheck.sh"
  "README.md"
  "LICENSE"
  "VERSION"
)

echo "Checking required files…"
for f in "${required_files[@]}"; do
  if [ ! -f "${PROJECT_DIR}/${f}" ]; then
    echo "❌ Missing file: ${f}"
    echo "Bundle cannot be created until all parts are present."
    exit 1
  fi
  echo "✔ ${f}"
done

echo
echo "Setting permissions…"
chmod +x "${PROJECT_DIR}/fluxpath-install.sh"
chmod +x "${PROJECT_DIR}/fluxpath-installer.sh"
chmod +x "${PROJECT_DIR}/fluxpath-precheck.sh"

echo "✔ Permissions updated"
echo

echo "Creating zip archive…"
cd "$HOME"
rm -f "${ZIP_NAME}"
zip -r "${ZIP_NAME}" "fluxpath-installer" >/dev/null

echo "✔ Archive created successfully"
echo
echo "──────────────────────────────────────────────"
echo " Bundle ready:"
echo "   $HOME/${ZIP_NAME}"
echo "──────────────────────────────────────────────"
echo
echo "You can now upload this zip to GitHub or attach it to a release."
