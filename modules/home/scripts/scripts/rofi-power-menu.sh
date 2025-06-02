#!/usr/bin/env bash

# Current Theme
dir="$HOME/.config/rofi/"
theme='power-menu'

# CMDs
uptime=$(uptime | sed 's/.*up *\([^,]*\).*/\1/')
host=$(hostname)

# Options - Display Strings (what Rofi shows)
shutdown_display='\Uf0425 Shutdown'
reboot_display='\Uf0709 Reboot'
lock_display='\Uf033e Lock'
yes_display='\Uf012c Yes'
no_display='\Uf0156 No'

# Internal Action Strings (what we match against)
# These should be simple strings without the Unicode escapes
shutdown_action="Shutdown"
reboot_action="Reboot"
lock_action="Lock"
yes_action="Yes"
no_action="No"

# Rofi CMD
rofi_cmd() {
	rofi -dmenu \
		-mesg "󱎫 Uptime: $uptime" \
		-theme "${dir}/${theme}.rasi"
}

# Confirmation CMD
confirm_cmd() {
	rofi -theme-str 'window {location: center; anchor: center; fullscreen: false; width: 250px;}' \
		-theme-str 'mainbox {children: [ "message", "listview" ];}' \
		-theme-str 'listview {columns: 2; lines: 1;}' \
		-theme-str 'element-text {horizontal-align: 0.5;}' \
		-theme-str 'textbox {horizontal-align: 0.5;}' \
		-dmenu \
		-p 'Confirmation' \
		-mesg 'Are you Sure?' \
		-theme "${dir}/${theme}.rasi"
}

# Ask for confirmation
confirm_exit() {
	# Here we echo the display strings, but capture the plain "Yes" or "No"
	echo -e "${yes_display}\n${no_display}" | confirm_cmd | sed 's/^\S* *//'
}

# Pass variables to rofi dmenu
run_rofi() {
	# We echo the display strings, but process the output to get just the action string
	echo -e "${lock_display}\n${reboot_display}\n${shutdown_display}" | \
		rofi_cmd | \
		sed 's/^\S* *//' # This sed command removes the first word (the icon) and any leading spaces
}

# Execute Command
run_cmd() {
	selected="$(confirm_exit)"
	if [[ "$selected" == "$yes_action" ]]; then # Match against the plain "Yes" action string
		if [[ "$1" == '--shutdown' ]]; then
			systemctl poweroff
		elif [[ "$1" == '--reboot' ]]; then
			systemctl reboot
		elif [[ "$1" == '--lock' ]]; then
			hyprlock
		fi
	else
		exit 0
	fi
}

# Actions
chosen="$(run_rofi)"
case "$chosen" in
"$shutdown_action")
	run_cmd --shutdown
	;;
"$reboot_action")
	run_cmd --reboot
	;;
"$lock_action")
	run_cmd --lock
	;;
esac