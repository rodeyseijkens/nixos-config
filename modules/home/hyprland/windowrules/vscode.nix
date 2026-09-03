{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(Code)$";
      center = true;
    }
    {
      match.class = "^(Code)$";
      float = true;
    }
  ];
}