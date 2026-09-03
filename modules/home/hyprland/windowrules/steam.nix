{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.float = true;
      match.title = "^(Steam)$";
      center = true;
    }
  ];
}