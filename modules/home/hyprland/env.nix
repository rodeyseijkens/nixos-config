{...}: let
  terminal = "ghostty";
in {
  wayland.windowManager.hyprland = {
    settings = {
      env = [
        "NIXOS_OZONE_WL, 1"
        "NIXPKGS_ALLOW_UNFREE, 1"
        "XDG_CURRENT_DESKTOP, Hyprland"
        "XDG_SESSION_TYPE, wayland"
        "XDG_SESSION_DESKTOP, Hyprland"
        "GDK_BACKEND, wayland, x11"
        "CLUTTER_BACKEND, wayland"
        "QT_QPA_PLATFORM=wayland;xcb"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION, 1"
        "QT_AUTO_SCREEN_SCALE_FACTOR, 1"
        "QT_QPA_PLATFORMTHEME, qt5ct"
        "QT_STYLE_OVERRIDE, kvantum"
        "DISABLE_QT5_COMPAT, 0"
        "SDL_VIDEODRIVER, x11"
        "MOZ_ENABLE_WAYLAND, 1"
        # This is to make electron apps start in wayland
        "ELECTRON_OZONE_PLATFORM_HINT,wayland"
        "ANKI_WAYLAND, 1"
        # Disabling this by default as it can result in inop cfg
        # Added card2 in case this gets enabled. For better coverage
        # This is mostly needed by Hybrid laptops.
        # but if you have multiple discrete GPUs this will set order
        #"AQ_DRM_DEVICES,/dev/dri/card0:/dev/dri/card1:/dev/card2"
        "GDK_SCALE,1"
        "QT_SCALE_FACTOR,1"
        "GTK_THEME, Colloid-Green-Dark-Gruvbox"
        # Graphics drivers settings
        "__GL_GSYNC_ALLOWED, 0"
        "__GL_VRR_ALLOWED, 0"
        # WLR (wlroots) settings
        "WLR_BACKEND, vulkan"
        "WLR_RENDERER, vulkan"
        "WLR_DRM_NO_ATOMIC, 1"
        "WLR_NO_HARDWARE_CURSORS, 1"
        # Application specific settings
        "SSH_AUTH_SOCK, /run/user/1000/keyring/ssh"
        "DIRENV_LOG_FORMAT, "
        "EDITOR,nvim"
        # Set terminal and xdg_terminal_emulator
        # To prevent yazi from starting xterm
        "TERMINAL,${terminal}"
        "XDG_TERMINAL_EMULATOR,${terminal}"
      ];
    };
  };
}
