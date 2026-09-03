{lib}: let
  inherit (lib.generators) mkLuaInline;

  # Convert an ini-style key string ("MODS, KEY") to Hyprland Lua format ("MODS + KEY").
  # Example: "SUPER SHIFT, Return" -> "SUPER + SHIFT + Return", ", Print" -> "Print"
  toLuaKey = key: let
    parts = lib.splitString ", " key;
  in
    if builtins.length parts > 1
    then let
      mods = lib.filter (s: s != "") (lib.splitString " " (builtins.elemAt parts 0));
      keyStr = builtins.elemAt parts 1;
    in
      if mods == []
      then keyStr
      else lib.concatStringsSep " + " mods + " + " + keyStr
    else key;

  # Map Hyprland legacy direction short-forms to the Lua API full words.
  dirName = dir:
    if dir == "l"
    then "left"
    else if dir == "r"
    then "right"
    else if dir == "u"
    then "up"
    else if dir == "d"
    then "down"
    else dir;

  # Map changegroupactive direction to the matching group dispatcher.
  groupDir = dir:
    if dir == "b"
    then "prev"
    else "next";
in rec {
  # Raw binding constructors
  bind = key: dsp: {_args = [(toLuaKey key) dsp];};
  bindWith = baseFlags: key: dsp: {_args = [(toLuaKey key) dsp baseFlags];};

  # Flag-preset variants (bakes in the modifier flags)
  bindLocked = bindWith {locked = true;};
  bindRepeat = bindWith {repeating = true;};
  bindLockedRepeat = bindWith {
    locked = true;
    repeating = true;
  };
  bindMouse = bindWith { };  # mouse: prefix in key suffices
  bindRelease = bindWith {release = true;};

  # Dispatch helpers — return mkLuaInline values
  exec = cmd: mkLuaInline ''hl.dsp.exec_cmd("${cmd}")'';
  execRaw = cmd: mkLuaInline "hl.dsp.exec_cmd([[${cmd}]])";

  killactive = mkLuaInline "hl.dsp.window.kill()";
  submap = name: mkLuaInline ''hl.dsp.submap("${name}")'';
  fullscreenToggle = mkLuaInline ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })'';
  fullscreenMaximize = mkLuaInline ''hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'';
  togglefloat = mkLuaInline ''hl.dsp.window.float({ action = "toggle" })'';
  pseudo = mkLuaInline "hl.dsp.window.pseudo()";

  movefocus = dir: mkLuaInline ''hl.dsp.focus({ direction = "${dirName dir}" })'';
  movewindow = dir: mkLuaInline ''hl.dsp.window.move({ direction = "${dirName dir}" })'';
  moveToWorkspace = n: mkLuaInline "hl.dsp.window.move({ workspace = ${toString n} })";
  moveToWorkspaceStr = n: mkLuaInline ''hl.dsp.window.move({ workspace = "${n}" })'';
  focusWorkspace = n: mkLuaInline "hl.dsp.focus({ workspace = ${toString n} })";

  resizeactive = x: y: mkLuaInline "hl.dsp.window.resize({ x = ${toString x}, y = ${toString y}, relative = true })";
  moveactive = x: y: mkLuaInline "hl.dsp.window.move({ x = ${toString x}, y = ${toString y}, relative = true })";
  layoutmsg = msg: mkLuaInline ''hl.dsp.layout("${msg}")'';

  togglegroup = mkLuaInline "hl.dsp.group.toggle()";
  changegroupactive = dir: mkLuaInline "hl.dsp.group.${groupDir dir}()";
  dragWindow = mkLuaInline "hl.dsp.window.drag()";
  resizeWindow = mkLuaInline "hl.dsp.window.resize()";
}
