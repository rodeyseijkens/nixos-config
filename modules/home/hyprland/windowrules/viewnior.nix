{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(.*Viewnior.*)$";
      float = true;
    }
    {
      match.class = "^(.*Viewnior.*)$";
      center = true;
    }
    {
      match.class = "^(.*Viewnior.*)$";
      size = "1200 800";
    }
  ];
}