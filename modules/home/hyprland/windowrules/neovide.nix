{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(.*neovide.*)$";
      tile = true;
    }
  ];
}