{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    # Generic float window rules
    "float true, match:class ^(file_progress)$"
    "float true, match:class ^(confirm)$"
    "float true, match:class ^(dialog)$"
    "float true, match:class ^(download)$"
    "float true, match:class ^(notification)$"
    "float true, match:class ^(error)$"
    "float true, match:class ^(confirmreset)$"
    "float true, match:title ^(Open Files?)$"
    "float true, match:title ^(File Uploads?)$"
    "float true, match:title ^(All Files)$"
    "float true, match:title ^(branchdialog)$"
    "float true, match:title ^(Confirm to replace files)$"
    "float true, match:title ^(File Operation Progress)$"

    # File upload specific rules
    "size 850 500, match:title ^(Open Files?)$"
    "size 850 500, match:title ^(File Uploads?)$"
    "size 850 500, match:title ^(All Files)$"

    # Volume control rules
    "float true, match:title ^(Volume Control)$"
    "size 700 450, match:title ^(Volume Control)$"
    "move 40 55%, match:title ^(Volume Control)$"

    # Sharing indicator rules
    "float true, match:title ^(.* — Sharing Indicator)$"
    "move 0 0, match:title ^(.* — Sharing Indicator)$"

    # Picture-in-Picture rules
    "float true, match:title ^(Picture-in-Picture)$"
    "opacity 1.0 override 1.0 override, match:title ^(Picture-in-Picture)$"
    "pin true, match:title ^(Picture-in-Picture)$"

    # XWayland video bridge rules
    "opacity 0.0 override, match:class ^(xwaylandvideobridge)$"
    "no_anim true, match:class ^(xwaylandvideobridge)$"
    "no_initial_focus true, match:class ^(xwaylandvideobridge)$"
    "max_size 1 1, match:class ^(xwaylandvideobridge)$"
    "no_blur true, match:class ^(xwaylandvideobridge)$"

    # Remove context menu transparency in chromium based apps
    "opaque true, match:class ^()$ match:title ^()$"
    "no_shadow true, match:class ^()$ match:title ^()$"
    "no_blur true, match:class ^()$ match:title ^()$"
  ];
}
