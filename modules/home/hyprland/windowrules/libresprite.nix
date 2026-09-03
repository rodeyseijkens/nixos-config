{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(libresprite)$";
      tile = true;
    }
  ];
}