#!/usr/bin/env bash

# Current Theme
dir="$HOME/.config/rofi/"
theme='power-menu'


# Options - Display Strings (what Rofi shows)
area_display='󰩬 Area'
fullscreen_display='󰹑 Fullscreen'
save_display=' Save to File'
swappy_display='󱇣 Edit with Swappy'
timer_display='󰄉 Timer'
timer5_display='󰔛 5s'
timer10_display='󱑎 10s'

# Titles
main_title="Screenshot"
header_title=' Take screenshot'

# Internal Action Strings (what we match against)
# These should be simple strings without the Unicode escapes
area_action="Area"
fullscreen_action="Fullscreen"
save_action="Save to File"
swappy_action="Edit with Swappy"
timer_action="Timer"
timer5_action="5s"
timer10_action="10s"

# Screenshot directory and file setup
dir_screenshots="$HOME/Pictures/Screenshots"
time=$(date +'%Y_%m_%d_at_%Hh%Mm%Ss')
file_name="screenshot_${time}.png"
file="${dir_screenshots}/${file_name}"

# Rofi CMD
rofi_cmd() {
	rofi -dmenu \
        -theme-str "window {width: 300px;}" \
		-theme-str "listview {columns: 1; lines: 5;}" \
		-mesg "$header_title" \
		-theme "${dir}/${theme}.rasi"
}

rofi_sub_cmd() {
	rofi -dmenu \
        -theme-str "window {width: 300px;}" \
		-theme-str "listview {columns: 1; lines: 2;}" \
		-mesg "$header_title" \
		-theme "${dir}/${theme}.rasi"
}

# Pass variables to rofi dmenu
run_rofi() {
	# We echo the display strings, but process the output to get just the action string
	echo -e "${area_display}\n${fullscreen_display}\n${save_display}\n${swappy_display}\n${timer_display}" | \
		rofi_cmd | \
		sed 's/^\S* *//' # This sed command removes the first word (the icon) and any leading spaces
}

run_sub_select() {
	# We echo the display strings, but process the output to get just the action string
	echo -e "${area_display}\n${fullscreen_display}" | \
		rofi_sub_cmd | \
		sed 's/^\S* *//' # This sed command removes the first word (the icon) and any leading spaces
}

run_time_select() {
	# We echo the display strings, but process the output to get just the action string
	echo -e "${timer5_display}\n${timer10_display}" | \
		rofi_sub_cmd | \
		sed 's/^\S* *//' # This sed command removes the first word (the icon) and any leading spaces
}

# Function to send notifications
notify() {
	if [ -z "$notification_id" ]; then
		notification_id=$(notify-send -a "$main_title" -p -t $2 "$main_title" "$1")
	else
		notify-send -a "$main_title" -t $2 --replace-id="$notification_id" "$main_title" "$1"
	fi
}

# countdown
countdown () {
	for sec in `seq $1 -1 1`; do
		notify "Taking shot in : $sec" 1100
		sleep 1
	done
}

# Screenshot functions
area_select() {
    grimblast copy area
	notify "Copied to clipboard" 3000
}

area_select_save() {
    grimblast save area "$file"
	notify "Saved \n$file_name" 3000
}

fullscreen() {
    sleep 0.7
    grimblast copy output
	notify "Copied to clipboard" 3000
}

fullscreen_save() {
    sleep 0.7
    grimblast save output "$file"
	notify "Saved \n$file_name" 3000
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

timer5() {
	countdown 5
	fullscreen_save
}

timer10() {
	countdown 10
	fullscreen_save
}

timer() {
    sub_chosen="$(run_time_select)"
    case "$sub_chosen" in
    "$timer5_action")
        timer5
        ;;
    "$timer10_action")
        timer10
        ;;
    esac
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
"$timer_action")
	timer
	;;
esac
