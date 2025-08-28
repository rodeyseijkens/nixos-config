#!/usr/bin/env bash

# Notification function
notify() {
	if [ -z "$notification_id" ]; then
		notification_id=$(notify-send -a "$1" -p -t $3 "$1" "$2")
	else
		notify-send -a "$1" -t $3 --replace-id="$notification_id" "$1" "$2"
	fi
}

# Plugin information for walker
info() {
    echo 'name = "󰑓 Reload services"
        placeholder = "Reload services"
        switcher_only = true
        parser = "kv"
        src_once = "yes"'
}

confirm() {
    local prompt="$1"
    # Use walker dmenu to ask Yes/No. Return 0 when confirmed.
    if echo -e "󰄬 Yes\n󰅖 No" | walker --dmenu -p "$prompt" -l 2 | grep -qx "󰄬 Yes"; then
        return 0
    fi
    return 1
}

do_hyprland() {
    hyprctl reload
}

do_waybar() {
    pkill -9 waybar || true
    sleep 0.5
    runbg waybar
}

do_swaync() {
    pkill -9 swaync || true
    sleep 0.5
    runbg swaync
}

do_walker() {
    pkill -9 walker || true
    sleep 0.5
    runbg walker --gapplication-service
}

do_all() {
    do_hyprland
    do_waybar
    do_swaync
    do_walker
}

entries() {
    local script="${BASH_SOURCE[0]}"
    cat <<EOF
label= All;exec=bash -lc '$script all';value=all;recalculate_score=true
label= Hyprland;exec=bash -lc '$script hyprland';value=hyprland;recalculate_score=true
label=󰍜 Waybar;exec=bash -lc '$script waybar';value=waybar;recalculate_score=true
label=󰂚 Swaync;exec=bash -lc '$script swaync';value=swaync;recalculate_score=true
label=󰌧 Walker;exec=bash -lc '$script walker';value=walker;recalculate_score=true
EOF
}

case "${1:-}" in
    info)
        info
        ;;
    entries)
        entries
        ;;
    hyprland)
        if confirm "Reload Hyprland?"; then
            if do_hyprland; then
                notify "Hyprland" "Hyprland reloaded" 2000
            else
                notify "Hyprland" "Failed to reload Hyprland" 5000
            fi
        fi
        ;;
    waybar)
        if confirm "Restart Waybar?"; then
            if do_waybar; then
                notify "Waybar" "Waybar restarted" 2000
            else
                notify "Waybar" "Failed to restart Waybar" 5000
            fi
        fi
        ;;
    swaync)
        if confirm "Restart Swaync?"; then
            if do_swaync; then
                notify "Swaync" "Swaync restarted" 2000
            else
                notify "Swaync" "Failed to restart Swaync" 5000
            fi
        fi
        ;;
    walker)
        if confirm "Restart Walker?"; then
            if do_walker; then
                notify "Walker" "Walker restarted" 2000
            else
                notify "Walker" "Failed to restart Walker" 5000
            fi
        fi
        ;;
    all)
        if confirm "Reload all services?"; then
            failures=0
            if ! do_hyprland; then failures=$((failures+1)); fi
            if ! do_waybar; then failures=$((failures+1)); fi
            if ! do_swaync; then failures=$((failures+1)); fi
            if ! do_walker; then failures=$((failures+1)); fi

            if [ "$failures" -eq 0 ]; then
                notify "Reload" "All services reloaded successfully" 3000
            else
                notify "Reload" "$failures services failed to restart" 5000
            fi
        fi
        ;;
    *)
        echo "Usage: $0 {info|entries|hyprland|waybar|swaync|walker|all}"
        exit 1
        ;;
esac
