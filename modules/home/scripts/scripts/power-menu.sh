#!/usr/bin/env bash

# Source the generic walker menu functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/walker-menu"

# Walker Power Menu
# Power management menu for Walker launcher
# Usage: power-menu.sh

# Titles
UPTIME=$(uptime | sed 's/.*up *\([^,]*\).*/\1/')
header_title="󱎫 Uptime: $UPTIME"

# Display Strings
shutdown_display='󰐥 Shutdown'
reboot_display='󰜉 Reboot'
lock_display='󰌾 Lock'
yes_display='󰄬 Yes'
no_display='󰅖 No'

# Power Menu Functions
show_power_menu() {
    case $(menu "$header_title" "$lock_display\n$reboot_display\n$shutdown_display" "" "") in
        *Lock*) 
            playerctl --all-players pause & hyprlock
            ;;
        *Reboot*) 
            show_power_confirm "reboot"
            ;;
        *Shutdown*) 
            show_power_confirm "shutdown"
            ;;
        *) 
            exit 0
            ;;
    esac
}

show_power_confirm() {
    local action="$1"
    local message="Are you sure you want to $action?"

    case $(menu "Confirmation" "$yes_display\n$no_display" "" "") in
        *Yes*)
            case "$action" in
                "reboot") 
                    notify "Rebooting system..."
                    sleep 1
                    systemctl reboot 
                    ;;
                "shutdown") 
                    notify "Shutting down system..."
                    sleep 1
                    systemctl poweroff 
                    ;;
            esac
            ;;
        *)
            exit 0;
            ;;
    esac
}

# Main execution - always show power menu
show_power_menu
