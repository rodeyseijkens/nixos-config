{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    "float true, match:class ^(zenity)$"
    "center true, match:class ^(zenity)$"
    "size 850 500, match:class ^(zenity)$"
  ];
}
