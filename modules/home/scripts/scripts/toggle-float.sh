#!/usr/bin/env bash

hyprctl dispatch "hl.dsp.window.float()"
hyprctl dispatch "hl.dsp.window.resize({ x = 950, y = 600, relative = true })"
hyprctl dispatch "hl.dsp.window.center()"
