#!/usr/bin/env bash

# Source the generic walker menu functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/walker-menu"

if (ps aux | grep mpv | grep -v grep > /dev/null) then
    killall -q mpv
else
    runbg mpv --no-video --shuffle "https://www.youtube.com/watch?list=PLURHk-dVe0Xl2Ax0KpmVsg1aCIkejPoAU"
	notify "Poolsuite FM" "Playing random track" 1100
fi