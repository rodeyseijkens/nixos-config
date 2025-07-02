{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    # Generic float window rules
    "float,class:^(file_progress)$"
    "float,class:^(confirm)$"
    "float,class:^(dialog)$"
    "float,class:^(download)$"
    "float,class:^(notification)$"
    "float,class:^(error)$"
    "float,class:^(confirmreset)$"
    "float,title:^(Open File)$"
    "float,title:^(File Upload)$"
    "float,title:^(branchdialog)$"
    "float,title:^(Confirm to replace files)$"
    "float,title:^(File Operation Progress)$"

    # File upload specific rules
    "size 850 500,title:^(File Upload)$"

    # Volume control rules
    "float,title:^(Volume Control)$"
    "size 700 450,title:^(Volume Control)$"
    "move 40 55%,title:^(Volume Control)$"

    # Sharing indicator rules
    "float,title:^(.* — Sharing Indicator)$"
    "move 0 0,title:^(.* — Sharing Indicator)$"

    # Picture-in-Picture rules
    "float, title:^(Picture-in-Picture)$"
    "opacity 1.0 override 1.0 override, title:^(Picture-in-Picture)$"
    "pin, title:^(Picture-in-Picture)$"

    # XWayland video bridge rules
    "opacity 0.0 override,class:^(xwaylandvideobridge)$"
    "noanim,class:^(xwaylandvideobridge)$"
    "noinitialfocus,class:^(xwaylandvideobridge)$"
    "maxsize 1 1,class:^(xwaylandvideobridge)$"
    "noblur,class:^(xwaylandvideobridge)$"

    # Remove context menu transparency in chromium based apps
    "opaque,class:^()$,title:^()$"
    "noshadow,class:^()$,title:^()$"
    "noblur,class:^()$,title:^()$"
  ];
}
