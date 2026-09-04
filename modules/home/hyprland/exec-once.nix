{lib, config, ...}: let
  toLua = lib.generators.toLua {};

  terminal = "ghostty";

  # Base startup commands, merged with contributions from other modules
  # (audio, swayosd) via config.modules.hyprland.startup.
  baseStartup = [
    "wl-clip-persist --clipboard regular"
    "wl-paste --type text --watch cliphist store"
    "wl-paste --type image --watch cliphist store"
    "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "systemctl --user start hyprpolkitagent"

    "killall -q waybar;sleep .5 && waybar"
    "killall -q swaync;sleep .5 && swaync"
    "killall -q elephant;sleep .5 && elephant"
    "killall -q walker;sleep .5 && walker --gapplication-service"
    "killall -q awww;sleep .5 && awww-daemon"

    "nm-applet --indicator"
    "poweralertd"

    "hyprlock"

    "${terminal} --gtk-single-instance=true --quit-after-last-window-closed=false --initial-window=false"
  ];

  # Render each command as hl.exec_cmd("…") inside a hl.on("hyprland.start", …)
  # handler. Hyprland's Lua API has no hl.exec_once; home-manager's
  # settings.exec_once would emit hl.exec_once(...) which Hyprland rejects.
  renderCmd = cmd: "  hl.exec_cmd(${toLua cmd})\n";
  startupLua = startupCmds: ''
    hl.on("hyprland.start", function()
    ${lib.concatMapStrings renderCmd startupCmds}end)
  '';
in {
  options.modules.hyprland = {
    startup = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Commands to run once at Hyprland startup.";
      apply = startupCmds: baseStartup ++ startupCmds;
    };
  };

  config.wayland.windowManager.hyprland.extraLuaFiles = {
    "startup" = {
      content = startupLua config.modules.hyprland.startup;
      autoLoad = true;
    };
  };
}
