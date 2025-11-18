{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    "float true, match:class ^(.*udiskie.*)$"
  ];
}
