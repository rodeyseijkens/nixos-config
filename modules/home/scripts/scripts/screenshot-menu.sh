#!/usr/bin/env bash

# Source the generic walker menu functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/walker-menu"

# Walker Screenshot Menu
# Screenshot functionality menu for Walker launcher
# Usage: screenshot-menu.sh

# Configuration
SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"

# Ensure screenshots directory exists
mkdir -p "$SCREENSHOTS_DIR"


# Titles
main_title="Screenshot"
header_title='  Take screenshot'

# Display Strings
area_display='󰩬  Area'
fullscreen_display='󰹑  Fullscreen'
save_display='  Save to File'
swappy_display='󱇣  Edit with Swappy'
timer_display='󰄉  Timer'
timer5_display='󰔛  5s'
timer10_display='󱑎  10s'

# Generic selection function for area/fullscreen choices
generic_area_fullscreen_selection() {
    local menu_title="$1"
    local area_action="$2"
    local fullscreen_action="$3"
    local fallback_action="$4"
    
    case $(menu "$menu_title" "$area_display\n$fullscreen_display" "" "") in
        *Area*) $area_action;;
        *Fullscreen*) $fullscreen_action;;
        *) $fallback_action;;
    esac
}

# Generate screenshot file path
get_screenshot_file() {
    local time=$(date +'%Y_%m_%d_at_%Hh%Mm%Ss')
    echo "${SCREENSHOTS_DIR}/screenshot_${time}.png"
}

# Countdown function for timed screenshots
countdown() {
    for sec in $(seq "$1" -1 1); do
        notify $main_title "Taking shot in: $sec seconds" 1100
        sleep 1
    done
}

# Screenshot Menu Functions
show_screenshot_menu() {
    case $(menu "$header_title" "$area_display\n$fullscreen_display\n$save_display\n$swappy_display\n$timer_display" "" "") in
        *Area*) screenshot_area;;
        *Fullscreen*) screenshot_fullscreen;;
        *Save*) save_file;;
        *Swappy*) screenshot_edit;;
        *Timer*) show_screenshot_timer_menu;;
        *) exit 0;;
    esac
}

show_screenshot_timer_menu() {
    case $(menu "Timer Screenshot" "$timer5_display\n$timer10_display" "" "") in
        *5*) screenshot_timer 5;;
        *10*) screenshot_timer 10;;
        *) exit 0;;
    esac
}

# Save file function - handles the sub-menu for saving screenshots
save_file() {
    generic_area_fullscreen_selection "$save_display" "screenshot_area_save" "screenshot_fullscreen_save" "show_screenshot_menu"
}

# Edit function - handles the sub-menu for editing screenshots
screenshot_edit() {
    generic_area_fullscreen_selection "$swappy_display" "screenshot_edit_area" "screenshot_edit_fullscreen" "show_screenshot_menu"
}

# Screenshot action functions
screenshot_area() {
    grimblast copy area
    notify $main_title "Copied to clipboard" 3000
}

screenshot_fullscreen() {
    sleep 0.7
    grimblast copy output
    notify $main_title "Copied to clipboard" 3000
}

screenshot_area_save() {
    local file=$(get_screenshot_file)
    grimblast save area "$file"
    notify $main_title "Saved \n$(basename "$file")" 3000
}

screenshot_fullscreen_save() {
    local file=$(get_screenshot_file)
    sleep 0.7
    grimblast save output "$file"
    notify $main_title "Saved \n$(basename "$file")" 3000
}

# Edit screenshot functions
screenshot_edit_area() {
    local file=$(get_screenshot_file)
    grimblast save area "$file"
    swappy -f "$file"
}

screenshot_edit_fullscreen() {
    local file=$(get_screenshot_file)
    sleep 0.7
    grimblast save output "$file"
    swappy -f "$file"
}

screenshot_timer() {
    local seconds="$1"
    local file=$(get_screenshot_file)
    
    countdown "$seconds"
    sleep 0.7
    grimblast save output "$file"
    notify $main_title "Saved \n$(basename "$file")" 3000
}

# Main execution - always show screenshot menu
show_screenshot_menu
