# FluxPath MMU – Quick Start
\

\
This guide walks you from zero to a working FluxPath MMU setup.
\

\
---
\

\
## 1. Folder setup
\

\
Create a FluxPath folder in your home directory:
\

\
\`\`\`bash
\
mkdir -p ~/FluxPath
\
cd ~/FluxPath
\
\`\`\`
\

\
Place these files in it:
\

\
- FluxPath_Installer_v0.9.0-beta.sh
\
- mmu_dashboard.sh
\
- fluxpath_skeleton.sh
\
- README.md
\
- CHANGELOG.md
\
- logo.txt
\
- docs/QUICKSTART.md
\
- fluidd/fluxpath_panel.json
\
- scripts/fluxpath_updater_stub.sh
\
- scripts/fluxpath_autodetect.sh
\
- mmu/mmu_calibration_wizard.cfg
\
- mmu/mmu_lane_test_wizard.cfg
\

\
---
\

\
## 2. Make the installer and dashboard executable
\

\
\`\`\`bash
\
cd ~/FluxPath
\
chmod +x FluxPath_Installer_v0.9.0-beta.sh
\
chmod +x mmu_dashboard.sh
\
\`\`\`
\

\
---
\

\
## 3. Run the installer
\

\
\`\`\`bash
\
./FluxPath_Installer_v0.9.0-beta.sh
\
\`\`\`
\

\
You will see the FluxPath banner and menu.
\

\
Recommended first actions:
\

\
1. Backup System
\
2. Dry-Run Install
\
3. Install FluxPath MMU
\

\
---
\

\
## 4. Install FluxPath MMU
\

\
From the menu:
\

\
1. Choose **Install FluxPath MMU**
\
2. Select whether to use the main Klipper instance or create a dedicated MMU instance
\
3. Enter:
\
   - Number of lanes (2–4)
\
   - Step/dir/enable pins for each MMU extruder
\
4. Optionally customize:
\
   - PARK→CUTTER distances
\
   - Cutter→Sensor
\
   - Sensor→Extruder
\
   - Nozzle push
\
   - Servo name and angles
\

\
The installer will generate all MMU config files under:
\

\
\`\`\`text
\
~/printer_data/config/mmu/
\
\`\`\`
\

\
---
\

\
## 5. Restart Klipper and Moonraker
\

\
Use the installer menu option:
\

\
- Restart Klipper/Moonraker
\

\
Then open your UI (Fluidd or Mainsail) and confirm Klipper starts cleanly.
\

\
---
\

\
## 6. Basic tests
\

\
In your UI console:
\

\
### Print MMU variables
\
\`\`\`gcode
\
MMU_UI_PRINT_VARS
\
\`\`\`
\

\
### Test lane selection
\
\`\`\`gcode
\
MMU_UI_SET_LANE LANE=1
\
MMU_UI_SET_LANE LANE=2
\
\`\`\`
\

\
### Test toolchange (after calibration)
\
\`\`\`gcode
\
T0
\
T1
\
\`\`\`
\

\
---
\

\
## 7. Use the dashboard
\

\
\`\`\`bash
\
cd ~/FluxPath
\
./mmu_dashboard.sh
\
\`\`\`
\

\
Dashboard keys:
\
- **E** → Emergency stop
\
- **Q** → Quit
\
- **R** → Refresh (manual mode)
\
- **A/M** → Auto/manual toggle
\

\
---
\

\
## 8. Calibration
\

\
Use the calibration helpers:
\

\
\`\`\`gcode
\
MMU_CAL_PARK_TO_CUTTER_LANE LANE=1
\
MMU_CAL_PARK_TO_CUTTER_LANE LANE=2
\
MMU_CAL_CUTTER_TO_FILAMENT_SENSOR
\
MMU_CAL_FILAMENT_SENSOR_TO_EXTRUDER
\
\`\`\`
\

\
For a guided flow, use the calibration wizard:
\

\
\`\`\`gcode
\
MMU_CAL_WIZARD_START
\
\`\`\`
\

\
---
\

\
## 9. Slicer setup
\

\
Use the generated slicer template:
\

\
\`\`\`text
\
~/printer_data/config/mmu/fluxpath_slicer_template.txt
\
\`\`\`
\

\
Tool mapping:
\
- T0 → Lane 1
\
- T1 → Lane 2
\
- T2 → Lane 3 (if configured)
\
- T3 → Lane 4 (if configured)
\

\
Keep slicer toolchange G-code minimal.
\

\
---
\

\
FluxPath MMU is created in Canada and enhanced by AI experience.
\
It is designed to be transparent, documented, and recoverable.
\

