{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(xdg-desktop-portal-gtk)$";
      match.title = "^(Open Folder)$";
      float = true;
    }
    {
      match.class = "^(xdg-desktop-portal-gtk)$";
      match.title = "^(Open Folder)$";
      size = "1000 650";
    }
    {
      match.class = "^(xdg-desktop-portal-gtk)$";
      match.title = "^(Open Folder)$";
      center = true;
    }
  ];
}
