{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(.*udiskie.*)$";
      float = true;
    }
  ];
}