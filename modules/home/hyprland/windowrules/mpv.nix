{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    "float,class:^(.*mpv.*)$"
    "center,class:^(.*mpv.*)$"
    "size 1200 725,class:^(.*mpv.*)$"
    "idleinhibit focus,class:^(.*mpv.*)$"
    "opacity 1.0 override 1.0 override, title:^(.*mpv.*)$"
    "idleinhibit focus, class:^(mpv)$"
  ];
}
