#!/usr/bin/env bash
# Reload/restart a single Hyprland-related service or all of them.
# Usage: reload-services <hyprland|waybar|swaync|walker|all>

notify() {
  notify-send "$1" "$2" -t "${3:-2000}" >/dev/null 2>&1 &
}

restart_hyprland() {
  hyprctl reload
  notify "Hyprland" "Hyprland restarted" 2000
}

restart_waybar() {
  killall -q -r 'waybar' || true
  sleep 0.5
  runbg waybar
  notify "Waybar" "Waybar restarted" 2000
}

restart_swaync() {
  killall -q -r 'swaync' || true
  sleep 0.5
  runbg swaync
  notify "Swaync" "Swaync restarted" 2000
}

restart_walker() {
  killall -q -r 'walker' || true
  sleep 0.5
  killall -q -r 'elephant' || true
  sleep 0.5
  runbg elephant
  sleep 1
  runbg walker --gapplication-service
  notify "Walker" "Walker restarted" 2000
}

restart_all() {
  hyprctl reload
  killall -q -r 'waybar' || true; sleep 0.5; runbg waybar
  killall -q -r 'swaync' || true; sleep 0.5; runbg swaync
  killall -q -r 'walker' || true; sleep 0.5
  killall -q -r 'elephant' || true; sleep 0.5
  runbg elephant; sleep 1
  runbg walker --gapplication-service
  notify "Reload" "All services restarted" 3000
}

case "${1:-}" in
  hyprland)  restart_hyprland ;;
  waybar)    restart_waybar ;;
  swaync)    restart_swaync ;;
  walker)    restart_walker ;;
  all)       restart_all ;;
  *)
    echo "Usage: $(basename "$0") <hyprland|waybar|swaync|walker|all>" >&2
    exit 1
    ;;
esac
