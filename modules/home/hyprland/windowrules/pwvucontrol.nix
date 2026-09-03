{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(com.saivert.pwvucontrol)$";
      float = true;
    }
  ];
}