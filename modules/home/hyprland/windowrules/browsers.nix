{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    # Firefox rules
    "idle_inhibit fullscreen, match:class ^(firefox)$"

    # Zen Browser rules
    "idle_inhibit fullscreen, match:class ^(zen-beta)$"

    # Google Chrome rules
    "idle_inhibit fullscreen, match:class ^(google-chrome)$"

    # Screen sharing notification rules for all browsers
    "float true, match:title ^(.* is sharing .*\.)$"
    "move 0 0, match:title ^(.* is sharing .*\.)$"
    "opacity 0.9 override 0.9 override, match:title ^(.* is sharing .*\.)$"
    "no_blur true, match:title ^(.* is sharing .*\.)$"
    "no_shadow true, match:title ^(.* is sharing .*\.)$"
  ];
}
