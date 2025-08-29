#!/usr/bin/env bash

# Walker Menu System - Generic Core
# A comprehensive menu system for Walker launcher
# Usage: walker-menu.sh [menu_name]

# Configuration
UPTIME=$(uptime | sed 's/.*up *\([^,]*\).*/\1/')
HOST=$(hostname)
OS=$(nixos-version | sed 's/\([0-9]*\.[0-9]*\).*/\1/')

# Menu function - core walker menu interface
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

# Notification function
notify() {
	if [ -z "$notification_id" ]; then
		notification_id=$(notify-send -a "$1" -p -t $3 "$1" "$2")
	else
		notify-send -a "$1" -t $3 --replace-id="$notification_id" "$1" "$2"
	fi
}

# System Info Menu
show_system_info() {
    local info="󱩛 Host: $HOST\n󱎫 Uptime: $UPTIME\n󰆦 OS: NixOS $OS\n󰒔 Kernel: $(uname -r)"
    case $(menu " System Info" "$info" "" "") in
        *)
            exit 0
            ;;
    esac
}

# Direct menu access function
go_to_menu() {
    case "${1,,}" in
        *apps*) walker -p "󱓞 Launch..." ;;
        *reload*) walker -m "󰑓 Reload services" ;;
        *screenshot*) walker -m " Screenshot" ;;
        *wallpapers*) walker -m "󰉏 Wallpapers" ;;
        *power*) power-menu ;;
        *system*) show_system_info ;;
        *) exit 0 ;;
    esac
}

# Main execution
if [[ -n "$1" ]]; then
    go_to_menu "$1"
fi
