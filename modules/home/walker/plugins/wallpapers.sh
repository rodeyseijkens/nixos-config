#!/usr/bin/env bash

# =============================================================================
# Walker Plugin: Wallpapers
# A plugin to display and set wallpapers using swww
# =============================================================================
WALLPAPERS_FOLDER="$HOME/nixos-config/wallpapers"
WALLPAPER_LIST=$(find "$WALLPAPERS_FOLDER" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | sort -V)

# Plugin information for walker
info() {
    echo 'name = "󰉏 Wallpapers"
        placeholder = "Wallpapers"
        switcher_only = true
        parser = "kv"
        src_once = "yes"'
}

# Generate wallpaper entries
entries() {
    while IFS= read -r path; do
        # Extract filename from path for the label excluding the extension
        local filename="${path##*/}"
        filename="${filename%.*}"

        echo "label=$filename;exec=wall-change $path -t none;image=$path;recalculate_score=true;value=$path"
    done <<< "$WALLPAPER_LIST"
}

case "$1" in
    info)
        info
        ;;
    entries)
        entries
        ;;
    *)
        echo "Usage: $0 {info|entries}"
        exit 1
        ;;
esac