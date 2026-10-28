{...}: let
  terminal = "ghostty";
  editor = "code";

  # Build a two-argument hl.env call: hl.env("NAME", "value").
  # The home-manager module renders { _args = [name value] } as
  # hl.env(name, value); a plain "NAME, value" string would be passed
  # as a single argument and rejected by Hyprland.
  env = name: value: {
    _args = [name value];
  };
in {
  wayland.windowManager.hyprland.settings = {
    env = [
      # Electron/Chromium and Firefox: use Wayland.
      (env "NIXOS_OZONE_WL" "1")
      (env "ELECTRON_OZONE_PLATFORM_HINT" "wayland")
      (env "MOZ_ENABLE_WAYLAND" "1")

      # Toolkits: prefer Wayland, fall back to X11.
      (env "GDK_BACKEND" "wayland,x11,*")
      (env "QT_QPA_PLATFORM" "wayland;xcb")
      (env "CLUTTER_BACKEND" "wayland")

      # Qt theming and scaling.
      (env "QT_QPA_PLATFORMTHEME" "qt6ct")
      (env "QT_STYLE_OVERRIDE" "kvantum")
      (env "QT_WAYLAND_DISABLE_WINDOWDECORATION" "1")
      (env "QT_AUTO_SCREEN_SCALE_FACTOR" "1")

      # App-specific Wayland switches.
      (env "ANKI_WAYLAND" "1")

      (env "GTK_THEME" "Colloid-Green-Dark-Gruvbox")
      (env "DIRENV_LOG_FORMAT" "")
      (env "EDITOR" editor)
      (env "TERMINAL" terminal)
      (env "XDG_TERMINAL_EMULATOR" terminal)
    ];
  };
}
