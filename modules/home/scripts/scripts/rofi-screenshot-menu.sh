#!/usr/bin/env bash

# Current Theme
dir="$HOME/.config/rofi/"
theme='power-menu'


# Options - Display Strings (what Rofi shows)
area_display='󰩬 Area'
fullscreen_display='󰹑 Fullscreen'
save_display=' Save to File'
swappy_display='󱇣 Edit with Swappy'

# Internal Action Strings (what we match against)
# These should be simple strings without the Unicode escapes
area_action="Area"
fullscreen_action="Fullscreen"
save_action="Save to File"
swappy_action="Edit with Swappy"

# Screenshot directory and file setup
dir_screenshots="$HOME/Pictures/Screenshots"
time=$(date +'%Y_%m_%d_at_%Hh%Mm%Ss')
file="${dir_screenshots}/Screenshot_${time}.png"

# Rofi CMD
rofi_cmd() {
	rofi -dmenu \
        -theme-str "window {width: 300px;}" \
		-theme-str "listview {columns: 1; lines: 4;}" \
		-mesg " Take screenshot" \
		-theme "${dir}/${theme}.rasi"
}

rofi_sub_cmd() {
	rofi -dmenu \
        -theme-str "window {width: 300px;}" \
		-theme-str "listview {columns: 1; lines: 2;}" \
		-mesg " Take screenshot" \
		-theme "${dir}/${theme}.rasi"
}

# Pass variables to rofi dmenu
run_rofi() {
	# We echo the display strings, but process the output to get just the action string
	echo -e "${area_display}\n${fullscreen_display}\n${save_display}\n${swappy_display}" | \
		rofi_cmd | \
		sed 's/^\S* *//' # This sed command removes the first word (the icon) and any leading spaces
}

run_sub_select() {
	# We echo the display strings, but process the output to get just the action string
	echo -e "${area_display}\n${fullscreen_display}" | \
		rofi_sub_cmd | \
		sed 's/^\S* *//' # This sed command removes the first word (the icon) and any leading spaces
}

# Screenshot functions
area_select() {
    grimblast --notify copy area
}

area_select_save() {
    grimblast --notify save area "$file"
}

fullscreen() {
    sleep 0.3
    grimblast --notify copy output
}

fullscreen_save() {
    sleep 0.3
    grimblast --notify save output "$file"
}

save_file() {
    sub_chosen="$(run_sub_select)"
    case "$sub_chosen" in
    "$area_action")
        area_select_save
        ;;
    "$fullscreen_action")
        fullscreen_save
        ;;
    esac
}

edit() {
    save_file
	swappy -f "$file"
}

# Actions
chosen="$(run_rofi)"
case "$chosen" in
"$area_action")
	area_select
	;;
"$fullscreen_action")
	fullscreen
	;;
"$save_action")
	save_file
	;;
"$swappy_action")
	edit
	;;
esac
