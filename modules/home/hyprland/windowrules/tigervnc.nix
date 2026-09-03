{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(Vncviewer)$";
      center = true;
    }
    {
      match.class = "^(Vncviewer)$";
      float = true;
    }
  ];
}