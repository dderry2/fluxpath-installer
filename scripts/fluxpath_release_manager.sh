#!/bin/bash

ROOT_DIR="$HOME/FluxPath"
SCRIPT_DIR="$ROOT_DIR/scripts"
BUILD_SCRIPT="$SCRIPT_DIR/fluxpath_build_release.sh"
PUBLISH_SCRIPT="$SCRIPT_DIR/fluxpath_publish_release.sh"
MOONRAKER_SANITY="$SCRIPT_DIR/fluxpath_moonraker_sanity.sh"

clear

echo "==============================================="
echo "        FluxPath Interactive Release Manager"
echo "==============================================="

while true; do
    echo ""
    echo "Choose an option:"
    echo "1) Build Release Artifact"
    echo "2) Publish Release to GitHub"
    echo "3) Auto‑Commit + Tag + Publish"
    echo "4) Validate Moonraker Config"
    echo "5) Exit"
    echo ""
    read -p "Selection: " choice

    case $choice in

        1)
            echo ""
            echo "--- Building Release Artifact ---"
            bash "$BUILD_SCRIPT"
            echo "DONE."
            ;;

        2)
            echo ""
            echo "--- Publishing Release to GitHub ---"
            bash "$PUBLISH_SCRIPT"
            echo "DONE."
            ;;

        3)
            echo ""
            echo "--- Auto‑Commit + Tag + Publish ---"
            cd "$ROOT_DIR"

            git add .
            git commit -m "Automated release commit"
            git push

            bash "$PUBLISH_SCRIPT"
            echo "DONE."
            ;;

        4)
            echo ""
            echo "--- Validating Moonraker Config ---"
            bash "$MOONRAKER_SANITY"
            echo "DONE."
            ;;

        5)
            echo ""
            echo "Exiting FluxPath Release Manager."
            exit 0
            ;;

        *)
            echo "Invalid selection."
            ;;
    esac
done
