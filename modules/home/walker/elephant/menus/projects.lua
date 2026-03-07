Name = "projects"
NamePretty = "Projects"
Description = "Open a project in your editor"

function GetEntries()
    local entries = {}
    local projects_dir = os.getenv("HOME") .. "/Projects"

    -- Find command:
    -- 1. Search in projects_dir
    -- 2. Only look at top-level directories (-maxdepth 1 -mindepth 1)
    -- 3. Only directories (-type d)
    -- 4. Sort alphabetically
    local cmd = "find '" .. projects_dir .. "' -maxdepth 1 -mindepth 1 -type d | sort -V"

    local handle = io.popen(cmd)
    
    if handle then
        for line in handle:lines() do
            local dirname = line:match("([^/]+)$")
            
            if dirname then
                table.insert(entries, {
                    Text = dirname,
                    Subtext = line,
                    Value = line,
                    Actions = {
                        -- Default action: Open in VSCode
                        activate = "code '" .. line .. "'",
                    }
                })
            end
        end
        handle:close()
    end

    return entries
end
