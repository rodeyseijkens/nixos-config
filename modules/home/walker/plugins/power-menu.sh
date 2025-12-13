#!/usr/bin/env bash

# Walker power script

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

# Display Strings
yes_display='󰄬 Yes'
no_display='󰅖 No'
lock_display='󰌾 Lock'
reboot_display='󰜉 Reboot'
shutdown_display='󰐥 Shutdown'

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

show_power_menu() {
    case $(menu "Power" "$lock_display\n$reboot_display\n$shutdown_display" "" "") in
        *Lock*) 
            playerctl --all-players pause & hyprlock 
            ;;
        *Reboot*) 
            show_power_confirm reboot 
            ;;
        *Shutdown*) 
            show_power_confirm shutdown 
            ;;
        *) 
            exit 0 
            ;;
    esac
}

case "$1" in
    lock)
        playerctl --all-players pause & hyprlock
        ;;
    reboot)
        show_power_confirm reboot
        ;;
    shutdown)
        show_power_confirm shutdown
        ;;
    menu|"")
        show_power_menu
        ;;
    *)
        echo "Usage: $0 {lock|reboot|shutdown|menu}"
        exit 1
        ;;
esac
