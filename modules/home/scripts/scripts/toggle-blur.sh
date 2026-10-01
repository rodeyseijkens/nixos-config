#!/usr/bin/env bash

# hyprctl keyword no longer works under Hyprland ≥0.55 Lua configs; route via eval.
if hyprctl getoption decoration:blur:enabled | grep "int: 1" >/dev/null ; then
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = false } } })' >/dev/null
else
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = true } } })' >/dev/null
fi
