{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    "float true, match:class ^(.*Viewnior.*)$"
    "center true, match:class ^(.*Viewnior.*)$"
    "size 1200 800, match:class ^(.*Viewnior.*)$"
  ];
}
