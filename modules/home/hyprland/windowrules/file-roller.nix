{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(org.gnome.FileRoller)$";
      float = true;
    }
    {
      match.class = "^(org.gnome.FileRoller)$";
      center = true;
    }
    {
      match.class = "^(org.gnome.FileRoller)$";
      size = "850 500";
    }
  ];
}