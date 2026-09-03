{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(zen-beta)$";
      idle_inhibit = "fullscreen";
    }
    {
      match.class = "^(google-chrome)$";
      idle_inhibit = "fullscreen";
    }
    {
      match.title = "^(.* is sharing .*\\.)$";
      float = true;
    }
    {
      match.title = "^(.* is sharing .*\\.)$";
      move = "0 0";
    }
    {
      match.title = "^(.* is sharing .*\\.)$";
      opacity = "0.9 override 0.9 override";
    }
    {
      match.title = "^(.* is sharing .*\\.)$";
      no_blur = true;
    }
    {
      match.title = "^(.* is sharing .*\\.)$";
      no_shadow = true;
    }
  ];
}