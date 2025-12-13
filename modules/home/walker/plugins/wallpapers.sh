#!/usr/bin/env bash

# =============================================================================
# Walker Script: Wallpapers
# A script to display and set wallpapers using swww
# =============================================================================
WALLPAPERS_FOLDER="$HOME/nixos-config/wallpapers"
WALLPAPER_LIST=$(find "$WALLPAPERS_FOLDER" -type d \( -name "raw" -o -name "generator" \) -prune -o -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print | sort -V)

menu() {
    local prompt="$1"
    local options="$2"
    local extra="$3"
    local preselect="$4"
    read -r -a args <<<"$extra"
    if [[ -n "$preselect" ]]; then
        local index
        index=$(echo -e "$options" | grep -nxF "$preselect" | cut -d: -f1)
        if [[ -n "$index" ]]; then
            args+=("-a" "$index")
        fi
    fi
    echo -e "$options" | walker --dmenu -p "$prompt" "${args[@]}" 2>/dev/null
}

# Generate wallpaper entries for dmenu
generate_entries() {
    while IFS= read -r path; do
        # Extract filename from path for the label excluding the extension
        local filename="${path##*/}"
        filename="${filename%.*}"
        echo "$filename"
    done <<< "$WALLPAPER_LIST"
}

show_wallpaper_menu() {
    local entries
    entries=$(generate_entries)
    
    local selected
    selected=$(menu "Wallpapers" "$entries" "" "")
    
    if [[ -n "$selected" ]]; then
        # Find the full path for the selected filename
        # This is a bit inefficient but simple. We assume filenames are unique enough or we pick the first match.
        # A better way would be to pass the path as a hidden value if walker dmenu supported it easily, 
        # or just map back.
        local selected_path
        selected_path=$(echo "$WALLPAPER_LIST" | grep -F "/$selected." | head -n 1)
        
        if [[ -n "$selected_path" ]]; then
            wall-change "$selected_path" -t none
        fi
    fi
}

show_wallpaper_menu
