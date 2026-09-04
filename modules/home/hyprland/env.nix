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
      (env "NIXOS_OZONE_WL" "1")
      (env "NIXPKGS_ALLOW_UNFREE" "1")
      (env "XDG_CURRENT_DESKTOP" "Hyprland")
      (env "XDG_SESSION_TYPE" "wayland")
      (env "XDG_SESSION_DESKTOP" "Hyprland")
      (env "GDK_BACKEND" "wayland,x11")
      (env "CLUTTER_BACKEND" "wayland")
      (env "QT_QPA_PLATFORM" "wayland;xcb")
      (env "QT_WAYLAND_DISABLE_WINDOWDECORATION" "1")
      (env "QT_AUTO_SCREEN_SCALE_FACTOR" "1")
      (env "QT_QPA_PLATFORMTHEME" "qt5ct")
      (env "QT_STYLE_OVERRIDE" "kvantum")
      (env "DISABLE_QT5_COMPAT" "0")
      (env "SDL_VIDEODRIVER" "x11")
      (env "MOZ_ENABLE_WAYLAND" "1")
      (env "ELECTRON_OZONE_PLATFORM_HINT" "wayland")
      (env "ANKI_WAYLAND" "1")
      (env "GDK_SCALE" "1")
      (env "QT_SCALE_FACTOR" "1")
      (env "GTK_THEME" "Colloid-Green-Dark-Gruvbox")
      (env "__GL_GSYNC_ALLOWED" "0")
      (env "__GL_VRR_ALLOWED" "0")
      (env "WLR_BACKEND" "vulkan")
      (env "WLR_RENDERER" "vulkan")
      (env "WLR_DRM_NO_ATOMIC" "1")
      (env "WLR_NO_HARDWARE_CURSORS" "1")
      (env "DIRENV_LOG_FORMAT" "")
      (env "EDITOR" editor)
      (env "TERMINAL" terminal)
      (env "XDG_TERMINAL_EMULATOR" terminal)
    ];
  };
}
