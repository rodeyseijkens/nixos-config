#!/usr/bin/env bash

# Walker power plugin

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

# Titles
UPTIME=$(uptime | sed 's/.*up *\([^,]*\).*/\1/')
header_title="󱎫 Uptime: $UPTIME"

# Display Strings
shutdown_display='󰐥 Shutdown'
reboot_display='󰜉 Reboot'
lock_display='󰌾 Lock'
yes_display='󰄬 Yes'
no_display='󰅖 No'

# Plugin information for walker
info() {
    echo 'name = "󰐥 Power menu"
        placeholder = "Power"
        switcher_only = true
        parser = "kv"
        src_once = "yes"'  
}

entries() {
    local script="${BASH_SOURCE[0]}"
    cat <<EOF
label=$lock_display;exec=bash -lc '$script lock';value=lock;recalculate_score=true
label=$reboot_display;exec=bash -lc '$script reboot';value=reboot;recalculate_score=true
label=$shutdown_display;exec=bash -lc '$script shutdown';value=shutdown;recalculate_score=true
EOF
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

case "$1" in
    info)
        info
        ;;
    entries)
        entries
        ;;
    lock)
        playerctl --all-players pause & hyprlock
        ;;
    reboot)
        show_power_confirm reboot
        ;;
    shutdown)
        show_power_confirm shutdown
        ;;
    *)
        echo "Usage: $0 {info|entries|lock|reboot|shutdown}"
        exit 1
        ;;
esac
