#!/usr/bin/env bash
# Reload/restart a single Hyprland-related service or all of them.
# Usage: reload-services <hyprland|walker|shell|all>

notify() {
  notify-send "$1" "$2" -t "${3:-2000}" >/dev/null 2>&1 &
}

restart_hyprland() {
  hyprctl reload
  notify "Hyprland" "Hyprland restarted" 2000
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

restart_shell() {
  systemctl --user restart quickshell
  notify "Quickshell" "Quickshell restarted" 2000
}

restart_all() {
  hyprctl reload
  systemctl --user restart quickshell
  killall -q -r 'walker' || true; sleep 0.5
  killall -q -r 'elephant' || true; sleep 0.5
  runbg elephant; sleep 1
  runbg walker --gapplication-service
  notify "Reload" "All services restarted" 3000
}

case "${1:-}" in
  hyprland) restart_hyprland ;;
  walker)   restart_walker ;;
  shell)    restart_shell ;;
  all)      restart_all ;;
  *)
    echo "Usage: $(basename "$0") <hyprland|walker|shell|all>" >&2
    exit 1
    ;;
esac
