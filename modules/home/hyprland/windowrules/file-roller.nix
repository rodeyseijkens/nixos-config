{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    "float true, match:class ^(org.gnome.FileRoller)$"
    "center true, match:class ^(org.gnome.FileRoller)$"
    "size 850 500, match:class ^(org.gnome.FileRoller)$"
  ];
}
