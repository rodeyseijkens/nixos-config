{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "(evince)";
      opacity = "1.0 override 1.0 override";
    }
  ];
}