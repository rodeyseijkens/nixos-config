#!/usr/bin/env bash

SERVICE=".waybar-wrapped"

if pgrep -x "$SERVICE" >/dev/null
then
  killall -q waybar
else
  runbg waybar
fi
