#!/bin/bash
set -e

BASE_DIR="/home/syko/FluxPath"
DOCS_DIR="$BASE_DIR/docs"

echo "=== Generating FluxPath Documentation Suite ==="
mkdir -p "$DOCS_DIR"

# README.md — Overview + Roadmap
cat > "$DOCS_DIR/README.md" << 'EOF'
# FluxPath Documentation

FluxPath is a next‑generation, machine‑independent MMU intelligence platform.  
It provides a unified FastAPI backend, real‑time WebSocket telemetry, and a modern architecture ready for slicer and web UI integration.

---

## 🚀 Next Steps Roadmap

1. **Integrate the Real MMU Engine**  
   - Expose MMU operations via API  
   - Broadcast MMU state via WebSocket  

2. **Bambu‑Style Slicer Integration**  
   - LAN discovery  
   - Job upload + control  
   - Telemetry streaming  

3. **Web UI (Mainsail/Fluidd)**  
   - Replace Moonraker  
   - Add MMU visualization, job queue, printer control  

4. **FluxPath CLI**  
   - `fluxpath status`  
   - `fluxpath mmu switch 3`  
   - `fluxpath print job.gcode`  

5. **Diagnostics Tool**  
   - systemd, port, venv, MMU hardware, slicer compatibility  

6. **Public Release Prep**  
   - API docs, onboarding, contribution guide, versioned releases  
EOF

# ROADMAP.md
cat > "$DOCS_DIR/ROADMAP.md" << 'EOF'
# FluxPath Roadmap

## Phase 1 — Foundation (Done)
- FastAPI backend  
- WebSocket  
- systemd service  
- repo cleanup  
- dashboard  

## Phase 2 — MMU Integration
- integrate real MMU engine  
- MMU API endpoints  
- MMU WebSocket telemetry  

## Phase 3 — Slicer Integration
- job upload  
- job control  
- telemetry  
- Bambu/Orca compatibility  

## Phase 4 — Web UI
- Mainsail/Fluidd integration  
- Moonraker‑compatible endpoints  
- MMU UI  
- job queue  
- printer control  

## Phase 5 — Developer Tools
- CLI  
- diagnostics  
- API docs  
- onboarding  

## Phase 6 — Public Release
- versioned tags  
- installers  
- community support  
EOF

# API.md
cat > "$DOCS_DIR/API.md" << 'EOF'
# FluxPath API Reference

## Health
GET /health

## Printer
GET /printer/info  
GET /printer/status  

## MMU (Planned)
GET /mmu/status  
POST /mmu/switch/{slot}  
POST /mmu/load  
POST /mmu/unload  
POST /mmu/reset  

## Slicer Integration (Planned)
GET /fluxpath/capabilities  
POST /print/upload  
POST /print/start  
POST /print/pause  
POST /print/cancel  

## WebSocket
GET /fluxpath/ws  
EOF

# MMU.md
cat > "$DOCS_DIR/MMU.md" << 'EOF'
# MMU Architecture

FluxPath’s MMU engine is modular and machine‑independent.

## Responsibilities
- slot switching  
- filament load/unload  
- jam detection  
- sensor feedback  
- state machine  
- error recovery  
- queue management  

## Integration Tasks
- import MMU engine into backend  
- expose MMU API  
- broadcast MMU state  
- update dashboard  
- integrate with slicers  
EOF

# WEBUI.md
cat > "$DOCS_DIR/WEBUI.md" << 'EOF'
# Web UI Integration (Mainsail/Fluidd)

Goal: FluxPath backend replaces Moonraker.

## Tasks
- implement Moonraker‑like endpoints  
- provide printer + MMU telemetry  
- add MMU control panel  
- add job queue  
- add real‑time updates  

## UI Features
- MMU visualization  
- filament inventory  
- slot switching  
- job control  
- telemetry  
- error logs  
EOF

# SLICER.md
cat > "$DOCS_DIR/SLICER.md" << 'EOF'
# Slicer Integration (Bambu/Orca)

FluxPath should behave like a LAN device.

## Requirements
- LAN discovery  
- capabilities endpoint  
- job upload  
- job control  
- telemetry  

## Targets
- OrcaSlicer  
- Bambu Studio (LAN mode)  

## MMU Reporting
- active slot  
- filament map  
- load/unload progress  
- jam/error states  
EOF

echo "=== Documentation generation complete ==="
