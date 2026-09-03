{...}: {
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(file_progress)$";
      float = true;
    }
    {
      match.class = "^(confirm)$";
      float = true;
    }
    {
      match.class = "^(dialog)$";
      float = true;
    }
    {
      match.class = "^(download)$";
      float = true;
    }
    {
      match.class = "^(notification)$";
      float = true;
    }
    {
      match.class = "^(error)$";
      float = true;
    }
    {
      match.class = "^(confirmreset)$";
      float = true;
    }
    {
      match.title = "^(Open Files?)$";
      float = true;
    }
    {
      match.title = "^(File Uploads?)$";
      float = true;
    }
    {
      match.title = "^(All Files)$";
      float = true;
    }
    {
      match.title = "^(branchdialog)$";
      float = true;
    }
    {
      match.title = "^(Confirm to replace files)$";
      float = true;
    }
    {
      match.title = "^(File Operation Progress)$";
      float = true;
    }
    {
      match.title = "^(Save File)$";
      float = true;
    }
    {
      match.title = "^(keyring)$";
      float = true;
    }
    {
      match.title = "^(keyring)$";
      pin = true;
    }
    {
      match.title = "^(keyring)$";
      opacity = "1.0 override 1.0 override";
    }
    {
      match.title = "^(keyring)$";
      stay_focused = true;
    }
    {
      match.title = "^(Open Files?)$";
      size = "850 500";
    }
    {
      match.title = "^(File Uploads?)$";
      size = "850 500";
    }
    {
      match.title = "^(All Files)$";
      size = "850 500";
    }
    {
      match.title = "^(Save File)$";
      size = "850 500";
    }
    {
      match.title = "^(Volume Control)$";
      float = true;
    }
    {
      match.title = "^(Volume Control)$";
      size = "700 450";
    }
    {
      match.title = "^(Volume Control)$";
      move = "40 55%";
    }
    {
      match.title = "^(.* — Sharing Indicator)$";
      float = true;
    }
    {
      match.title = "^(.* — Sharing Indicator)$";
      move = "0 0";
    }
    {
      match.title = "^(Picture-in-Picture)$";
      float = true;
    }
    {
      match.title = "^(Picture-in-Picture)$";
      opacity = "1.0 override 1.0 override";
    }
    {
      match.title = "^(Picture-in-Picture)$";
      pin = true;
    }
    {
      match.class = "^(xwaylandvideobridge)$";
      opacity = "0.0 override";
    }
    {
      match.class = "^(xwaylandvideobridge)$";
      no_anim = true;
    }
    {
      match.class = "^(xwaylandvideobridge)$";
      no_initial_focus = true;
    }
    {
      match.class = "^(xwaylandvideobridge)$";
      max_size = "1 1";
    }
    {
      match.class = "^(xwaylandvideobridge)$";
      no_blur = true;
    }
    {
      match.class = "^()$";
      match.title = "^()$";
      opaque = true;
    }
    {
      match.class = "^()$";
      match.title = "^()$";
      no_shadow = true;
    }
    {
      match.class = "^()$";
      match.title = "^()$";
      no_blur = true;
    }
  ];
}