{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(.*mpv.*)$";
      float = true;
    }
    {
      match.class = "^(.*mpv.*)$";
      center = true;
    }
    {
      match.class = "^(.*mpv.*)$";
      size = "1200 725";
    }
    {
      match.class = "^(.*mpv.*)$";
      idle_inhibit = "focus";
    }
    {
      match.title = "^(.*mpv.*)$";
      opacity = "1.0 override 1.0 override";
    }
    {
      match.class = "^(mpv)$";
      idle_inhibit = "focus";
    }
  ];
}