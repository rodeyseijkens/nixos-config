{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    # Firefox rules
    "idleinhibit fullscreen, class:^(firefox)$"

    # Zen Browser rules
    "idleinhibit fullscreen, class:^(zen-beta)$"

    # Google Chrome rules
    "idleinhibit fullscreen, class:^(google-chrome)$"

    # Screen sharing notification rules for all browsers
    "float,title:^(.* is sharing .*\.)$"
    "move 0 0,title:^(.* is sharing .*\.)$"
    "opacity 0.9 override 0.9 override,title:^(.* is sharing .*\.)$"
    "noblur,title:^(.* is sharing .*\.)$"
    "noshadow,title:^(.* is sharing .*\.)$"
  ];
}
