#!/usr/bin/env bash

# Configuration
SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOTS_DIR"

# Notification function
notify() {
    if [ -z "$notification_id" ]; then
        notification_id=$(notify-send -a "Screenshot" -p -t $2 "$1")
    else
        notify-send -a "Screenshot" -t $2 --replace-id="$notification_id" "$1"
    fi
}

get_screenshot_file() {
    local time
    time=$(date +'%Y_%m_%d_at_%Hh%Mm%Ss')
    echo "${SCREENSHOTS_DIR}/screenshot_${time}.png"
}

countdown() {
    for sec in $(seq "$1" -1 1); do
        notify "Taking shot in: $sec seconds" 1100
        sleep 1
    done
}

# Actions
copy_area() {
    grimblast copy area
    notify "Copied to clipboard" 3000
}

copy_output() {
    sleep 0.7
    grimblast copy output
    notify "Copied to clipboard" 3000
}

save_area() {
    local file
    file=$(get_screenshot_file)
    grimblast save area "$file"
    notify "Saved \n$(basename "$file")" 3000
}

save_output() {
    local file
    file=$(get_screenshot_file)
    sleep 0.7
    grimblast save output "$file"
    notify "Saved \n$(basename "$file")" 3000
}

edit_area() {
    local file
    file=$(get_screenshot_file)
    grimblast save area "$file"
    satty -f "$file"
}

edit_output() {
    local file
    file=$(get_screenshot_file)
    sleep 0.7
    grimblast save output "$file"
    satty -f "$file"
}

timer() {
    local seconds="$1"
    local file
    file=$(get_screenshot_file)

    countdown "$seconds"
    sleep 0.7
    grimblast save output "$file"
    notify "Saved \n$(basename "$file")" 3000
}

case "$1" in
    copy-area) copy_area ;;
    copy-output) copy_output ;;
    save-area) save_area ;;
    save-output) save_output ;;
    edit-area) edit_area ;;
    edit-output) edit_output ;;
    timer) timer "$2" ;;
    *) echo "Usage: $0 {copy-area|copy-output|save-area|save-output|edit-area|edit-output|timer <seconds>}"; exit 1 ;;
esac
