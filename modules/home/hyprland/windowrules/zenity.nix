{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(zenity)$";
      float = true;
    }
    {
      match.class = "^(zenity)$";
      center = true;
    }
    {
      match.class = "^(zenity)$";
      size = "850 500";
    }
  ];
}