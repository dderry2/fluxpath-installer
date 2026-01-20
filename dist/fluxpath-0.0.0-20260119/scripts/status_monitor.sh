#!/bin/bash
set -e

LOGO=$(cat << 'BEOF'
  __ _  _  ___   _____  __ _____ _  _  
| __| || || \ \_/ / _,\/  \_   _| || | 
| _|| || \/ |> , <| v_/ /\ || | | >< | 
|_| |___\__//_/ \_\_| |_||_||_| |_||_| 
BEOF
)

get_backend_health_raw() { curl -s http://localhost:9876/health 2>/dev/null || echo "unreachable"; }
get_printer_info_raw()  { curl -s http://localhost:7125/printer/info 2>/dev/null || echo "unreachable"; }
get_mmu_status_raw()    { curl -s http://localhost:9876/mmu/status 2>/dev/null || echo "unreachable"; }
get_mmu_sensors_raw()   { curl -s http://localhost:9876/sensors 2>/dev/null || echo "unreachable"; }
get_mmu_motors_raw()    { curl -s http://localhost:9876/motors 2>/dev/null || echo "unreachable"; }
get_webcam_status_raw() { curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/?action=snapshot" 2>/dev/null || echo "unreachable"; }

backend_service_state() {
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet fluxpath.service; then
    echo "active"
  else
    echo "inactive"
  fi
}

fmt_status() {
  local label="$1"
  local raw="$2"
  if [[ "$raw" == "unreachable" ]]; then
    echo "✖ $label: unreachable"
  elif echo "$raw" | grep -q '"detail":"Not Found"'; then
    echo "⚠ $label: endpoint not found"
  else
    echo "✔ $label: $raw"
  fi
}

fmt_webcam() {
  local code="$1"
  if [[ "$code" == "unreachable" ]]; then
    echo "✖ Webcam: unreachable"
  elif [[ "$code" =~ ^[0-9]+$ ]] && [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
    echo "✔ Webcam HTTP: $code"
  else
    echo "⚠ Webcam HTTP: $code"
  fi
}

show_status_loop() {
  while true; do
    backend_state=$(backend_service_state)
    backend_health=$(get_backend_health_raw)
    printer=$(get_printer_info_raw)
    mmu_status=$(get_mmu_status_raw)
    mmu_sensors=$(get_mmu_sensors_raw)
    mmu_motors=$(get_mmu_motors_raw)
    webcam=$(get_webcam_status_raw)

    clear
    echo "$LOGO"
    echo
    echo "FluxPath Status Monitor"
    echo "------------------------"
    echo "$(fmt_status 'Backend service' "$backend_state")"
    echo "$(fmt_status 'Backend health' "$backend_health")"
    echo
    echo "$(fmt_status 'Printer API' "$printer")"
    echo
    echo "$(fmt_status 'MMU status' "$mmu_status")"
    echo "$(fmt_status 'MMU sensors' "$mmu_sensors")"
    echo "$(fmt_status 'MMU motors' "$mmu_motors")"
    echo
    echo "$(fmt_webcam "$webcam")"
    echo
    echo "Press Ctrl+C to exit."
    sleep 3
  done
}

show_status_loop
