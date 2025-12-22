Name = "wallpapers"
NamePretty = "Wallpapers"
Description = "Select a wallpaper"

function GetEntries()
    local entries = {}
    local wallpaper_dir = os.getenv("HOME") .. "/nixos-config/wallpapers"

    -- Find command:
    -- 1. Search in wallpaper_dir
    -- 2. Exclude 'raw' and 'generator' directories (prune)
    -- 3. Look for image files
    -- 4. Print matches
    local cmd = "find '" .. wallpaper_dir .. "' -type d \\( -name 'raw' -o -name 'generator' \\) -prune -o -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \\) -print | sort -V"

    local handle = io.popen(cmd)
    
    if handle then
        for line in handle:lines() do
            local filename = line:match("([^/]+)$")
            -- Remove extension for display text
            local display_text = filename:match("(.+)%..+$") or filename

            if filename then
                table.insert(entries, {
                    Text = display_text,
                    Subtext = "Wallpaper",
                    -- The value isn't strictly needed if we define the action directly, 
                    -- but good for debugging or if we use %VALUE%
                    Value = line, 
                    Preview = line,
                    PreviewType = "file",
                    Actions = {
                        -- The main action when selecting an entry
                        activate = "wall-change '" .. line .. "' -t none",
                    }
                })
            end
        end
        handle:close()
    end

    return entries
end
