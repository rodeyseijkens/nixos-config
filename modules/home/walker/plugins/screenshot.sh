#!/usr/bin/env bash

# Notification function
notify() {
    if [ -z "$notification_id" ]; then
        notification_id=$(notify-send -a "$1" -p -t $3 "$1" "$2")
    else
        notify-send -a "$1" -t $3 --replace-id="$notification_id" "$1" "$2"
    fi
}

# Menu function
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

# Configuration
SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOTS_DIR"

# Titles and display strings
main_title="Screenshot"
header_title=' Take screenshot'
area_display='󰩬 Area'
fullscreen_display='󰹑 Fullscreen'
save_display=' Save to File'
satty_display='󱇣 Edit with Satty'
timer_display='󰄉 Timer'
timer5_display='󰔛 5s'
timer10_display='󱑎 10s'

get_screenshot_file() {
    local time
    time=$(date +'%Y_%m_%d_at_%Hh%Mm%Ss')
    echo "${SCREENSHOTS_DIR}/screenshot_${time}.png"
}

countdown() {
    for sec in $(seq "$1" -1 1); do
        notify "$main_title" "Taking shot in: $sec seconds" 1100
        sleep 1
    done
}

generic_area_fullscreen_selection() {
    local menu_title="$1"
    local area_action="$2"
    local fullscreen_action="$3"
    local fallback_action="$4"

    case $(menu "$menu_title" "$area_display\n$fullscreen_display" "" "") in
        *Area*) $area_action ;;
        *Fullscreen*) $fullscreen_action ;;
        *) $fallback_action ;;
    esac
}

# Actions
screenshot_area() {
    grimblast copy area
    notify "$main_title" "Copied to clipboard" 3000
}

screenshot_fullscreen() {
    sleep 0.7
    grimblast copy output
    notify "$main_title" "Copied to clipboard" 3000
}

screenshot_area_save() {
    local file
    file=$(get_screenshot_file)
    grimblast save area "$file"
    notify "$main_title" "Saved \n$(basename "$file")" 3000
}

screenshot_fullscreen_save() {
    local file
    file=$(get_screenshot_file)
    sleep 0.7
    grimblast save output "$file"
    notify "$main_title" "Saved \n$(basename "$file")" 3000
}

screenshot_edit_area() {
    local file
    file=$(get_screenshot_file)
    grimblast save area "$file"
    satty -f "$file"
}

screenshot_edit_fullscreen() {
    local file
    file=$(get_screenshot_file)
    sleep 0.7
    grimblast save output "$file"
    satty -f "$file"
}

screenshot_timer() {
    local seconds="$1"
    local file
    file=$(get_screenshot_file)

    countdown "$seconds"
    sleep 0.7
    grimblast save output "$file"
    notify "$main_title" "Saved \n$(basename "$file")" 3000
}

show_screenshot_timer_menu() {
    case $(menu "Timer Screenshot" "$timer5_display\n$timer10_display" "" "") in
        *5*) screenshot_timer 5 ;;
        *10*) screenshot_timer 10 ;;
        *) show_screenshot_menu ;;
    esac
}

show_screenshot_menu() {
    case $(menu "$header_title" "$area_display\n$fullscreen_display\n$save_display\n$satty_display\n$timer_display" "" "") in
        *Area*) screenshot_area ;;
        *Fullscreen*) screenshot_fullscreen ;;
        *Save*) generic_area_fullscreen_selection "$save_display" screenshot_area_save screenshot_fullscreen_save show_screenshot_menu ;;
        *Satty*) generic_area_fullscreen_selection "$satty_display" screenshot_edit_area screenshot_edit_fullscreen show_screenshot_menu ;;
        *Timer*) show_screenshot_timer_menu ;;
        *) exit 0 ;;
    esac
}

case "$1" in
    area) screenshot_area ;;
    fullscreen) screenshot_fullscreen ;;
    save) generic_area_fullscreen_selection "$save_display" screenshot_area_save screenshot_fullscreen_save show_screenshot_menu ;;
    satty) generic_area_fullscreen_selection "$satty_display" screenshot_edit_area screenshot_edit_fullscreen show_screenshot_menu ;;
    timer) show_screenshot_timer_menu ;;
    menu|"") show_screenshot_menu ;;
    *) echo "Usage: $0 {menu|area|fullscreen|save|satty|timer}"; exit 1 ;;
esac
