#!/usr/bin/env bash

# Notification function
notify() {
	if [ -z "$notification_id" ]; then
		notification_id=$(notify-send -a "$1" -p -t $3 "$1" "$2")
	else
		notify-send -a "$1" -t $3 --replace-id="$notification_id" "$1" "$2"
	fi
}

menu() {
    local prompt="$1"
    local options="$2"
    local extra="$3"
    local preselect="$4"
    read -r -a args <<<"$extra"
    if [[ -n "$preselect" ]]; then
        local index
        index=$(echo -e "$options" | grep -nxF "$preselect" | cut -d: -f1)
        if [[ -n "$index" ]]; then
            args+=("-a" "$index")
        fi
    fi
    echo -e "$options" | walker --dmenu -p "$prompt" "${args[@]}" 2>/dev/null
}

confirm() {
    local prompt="$1"
    # Use walker dmenu to ask Yes/No. Return 0 when confirmed.
    if echo -e "󰄬 Yes\n󰅖 No" | walker --dmenu -p "$prompt" | grep -qx "󰄬 Yes"; then
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
    pkill -9 elephant || true
    sleep 0.5
    runbg elephant
    runbg walker --gapplication-service
}

do_all() {
    do_hyprland
    do_waybar
    do_swaync
    do_walker
}

show_reload_menu() {
    case $(menu "Reload" " All\n Hyprland\n󰍜 Waybar\n󰂚 Swaync\n󰌧 Walker" "" "") in
        *All*)
            if confirm "Reload all services?"; then
                do_all
                notify "Reload" "All services reloaded" 3000
            fi
            ;;
        *Hyprland*)
            if confirm "Reload Hyprland?"; then
                do_hyprland
                notify "Hyprland" "Hyprland reloaded" 2000
            fi
            ;;
        *Waybar*)
            if confirm "Restart Waybar?"; then
                do_waybar
                notify "Waybar" "Waybar restarted" 2000
            fi
            ;;
        *Swaync*)
            if confirm "Restart Swaync?"; then
                do_swaync
                notify "Swaync" "Swaync restarted" 2000
            fi
            ;;
        *Walker*)
            if confirm "Restart Walker?"; then
                do_walker
                notify "Walker" "Walker restarted" 2000
            fi
            ;;
        *)
            exit 0
            ;;
    esac
}

show_reload_menu
