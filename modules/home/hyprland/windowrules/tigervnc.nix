{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    "center true, match:class ^(Vncviewer)$"
    "float true, match:class ^(Vncviewer)$"
  ];
}
