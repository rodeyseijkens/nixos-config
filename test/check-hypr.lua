-- Runtime checker for a Hyprland Lua config.
--
-- hyprvalidate only checks against the hl.meta.lua stub, which declares many
-- functions as `fun(...): any` (variadic), so it cannot catch arity or argument
-- type errors — the exact class of bug that bit us with `hl.env`. This script
-- loads the generated config in a real Lua interpreter with a mock `hl` table
-- whose functions enforce the REAL arity/type rules observed in Hyprland.
--
-- Usage: lua check-hypr.lua <config.lua>

local config_path = arg[1]
if not config_path then
  io.stderr:write("usage: lua check-hypr.lua <config.lua>\n")
  os.exit(2)
end

-- Make require() find sibling Lua files (e.g. extraLuaFiles like startup.lua)
-- that Hyprland would load from the same config directory.
local config_dir = config_path:match("^(.*[/\\])") or "./"
package.path = config_dir .. "?.lua;" .. config_dir .. "?/init.lua;" .. package.path

local findings = {}

local function add(name, msg)
  table.insert(findings, string.format("%s: %s", name, msg))
end

-- Build a function factory that checks arg count and arg types.
local function fn(name, spec)
  return function(...)
    local n = select("#", ...)
    local args = { ... }
    if spec.min and n < spec.min then
      add(name, string.format("got %d argument(s), expected at least %d", n, spec.min))
    end
    if spec.max and n > spec.max then
      add(name, string.format("got %d argument(s), expected at most %d", n, spec.max))
    end
    if spec.types then
      for i, t in ipairs(spec.types) do
        local v = args[i]
        if v ~= nil and type(v) ~= t then
          add(name, string.format("argument %d must be %s, got %s", i, t, type(v)))
        end
      end
    end
    -- Mirror Hyprland: return nil unless the real API returns something useful.
    return nil
  end
end

-- The dispatcher namespace (hl.dsp.*). These are variadic dispatcher
-- FACTORIES (the stub declares them `fun(...): HL.Dispatcher`): they may be
-- called with 0 args (e.g. mouse-driven drag/resize) or with a spec table, so
-- we only enforce that they are callable — not a specific arity.
local function dsp_fn(name)
  return function(...)
    return nil
  end
end

local dsp = {
  exec_cmd = dsp_fn("hl.dsp.exec_cmd"),
  submap = dsp_fn("hl.dsp.submap"),
  layout = dsp_fn("hl.dsp.layout"),
  focus = dsp_fn("hl.dsp.focus"),
  window = {
    move = dsp_fn("hl.dsp.window.move"),
    resize = dsp_fn("hl.dsp.window.resize"),
    kill = dsp_fn("hl.dsp.window.kill"),
    fullscreen = dsp_fn("hl.dsp.window.fullscreen"),
    float = dsp_fn("hl.dsp.window.float"),
    pseudo = dsp_fn("hl.dsp.window.pseudo"),
    drag = dsp_fn("hl.dsp.window.drag"),
  },
  group = {
    toggle = dsp_fn("hl.dsp.group.toggle"),
    prev = dsp_fn("hl.dsp.group.prev"),
    next = dsp_fn("hl.dsp.group.next"),
  },
}

-- The top-level hl API.
local hl = {
  dsp = dsp,

  -- env(name, value): exactly 2 string args. This is what caught us.
  env = fn("hl.env", { min = 2, max = 2, types = { "string", "string" } }),

  -- bind(keys, dispatcher, opts?): at least 2 args.
  bind = fn("hl.bind", { min = 2 }),

  -- exec_cmd(cmd, rules?)
  exec_cmd = fn("hl.exec_cmd", { min = 1 }),

  -- config(opts)
  config = fn("hl.config", { min = 1 }),

  -- monitor(spec)
  monitor = fn("hl.monitor", { min = 1 }),

  -- window_rule(spec)
  window_rule = fn("hl.window_rule", { min = 1 }),

  -- on(event, callback)
  on = fn("hl.on", { min = 2 }),

  -- define_submap(name, reset_or_fn, fn?)
  define_submap = fn("hl.define_submap", { min = 1 }),
}

-- Unknown hl.* references should be flagged, not silently accepted.
setmetatable(hl, {
  __index = function(_, key)
    error(string.format("unknown function hl.%s", key), 2)
  end,
})

-- Hyprland exposes `hl` as a global; the generated config uses it directly.
_G.hl = hl

-- Execute the config in this guarded environment.
local chunk, err = loadfile(config_path)
if not chunk then
  io.stderr:write("error loading config: " .. tostring(err) .. "\n")
  os.exit(2)
end

-- Run inside a protected call so the whole file runs and we can report every
-- arity/type problem, even after a bad call, rather than stopping at line 1.
local ok, runtime_err = pcall(chunk)
if not ok then
  table.insert(findings, string.format("runtime error: %s", runtime_err))
end

if #findings > 0 then
  io.stderr:write(string.format("%d issue(s) found:\n", #findings))
  for _, f in ipairs(findings) do
    io.stderr:write("  " .. f .. "\n")
  end
  os.exit(1)
else
  print("No issues found.")
end
