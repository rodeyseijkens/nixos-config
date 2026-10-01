#!/usr/bin/env bash

# hyprctl keyword no longer works under Hyprland ≥0.55 Lua configs; route via eval.
if hyprctl getoption decoration:active_opacity | grep "float: 1" >/dev/null ; then
    hyprctl eval 'hl.config({ decoration = { active_opacity = 0.9, inactive_opacity = 0.9 } })' >/dev/null
else
    hyprctl eval 'hl.config({ decoration = { active_opacity = 1, inactive_opacity = 1 } })' >/dev/null
fi
