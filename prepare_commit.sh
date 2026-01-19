#!/bin/bash
set -e

BASE_DIR="/home/syko/FluxPath"
cd "$BASE_DIR"

echo "=== Cleaning repo ==="
find "$BASE_DIR" -type d -name "__pycache__" -exec rm -rf {} + || true

echo "=== Staging changes ==="
git add -A

if git diff --cached --quiet; then
    echo "No changes to commit."
    exit 0
fi

echo "=== Committing ==="
git commit -m "Add full documentation suite and clean repo for GitHub push"

echo "=== Pushing ==="
git push

echo "=== GitHub commit complete ==="
