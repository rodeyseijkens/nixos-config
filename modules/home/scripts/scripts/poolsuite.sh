#!/usr/bin/env bash

# Function to send notifications
notify() {
	if [ -z "$notification_id" ]; then
		notification_id=$(notify-send -a "$main_title" -p -t $2 "$main_title" "$1")
	else
		notify-send -a "$main_title" -t $2 --replace-id="$notification_id" "$main_title" "$1"
	fi
}

if (ps aux | grep mpv | grep -v grep > /dev/null) then
    pkill mpv
else
    runbg mpv --no-video --shuffle "https://youtube.com/playlist?list=PLjgfRsNVysApcYyZYU8H6FB_eupl7QlTF"
    notify "Poolsuite FM started" 2000
fi