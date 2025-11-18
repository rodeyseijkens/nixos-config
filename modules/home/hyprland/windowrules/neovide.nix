{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    "tile true, match:class ^(.*neovide.*)$"
  ];
}
