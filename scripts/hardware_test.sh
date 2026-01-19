#!/bin/bash
set -e

LOGO=$(cat << 'BEOF'
  __ _  _  ___   _____  __ _____ _  _  
| __| || || \ \_/ / _,\/  \_   _| || | 
| _|| || \/ |> , <| v_/ /\ || | | >< | 
|_| |___\__//_/ \_\_| |_||_||_| |_||_| 
BEOF
)

whiptail --title "FluxPath Hardware Tools" --msgbox "$LOGO

Hardware tools are not implemented yet.

This script is reserved for:
- MMU homing
- Self-tests
- Sensor checks
- Slot calibration

For now, all behavior is read-only and defined in other tools." 20 80
