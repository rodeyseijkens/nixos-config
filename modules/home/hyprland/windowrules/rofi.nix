{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    "pin,class:^(.*rofi.*)$"
  ];
}
