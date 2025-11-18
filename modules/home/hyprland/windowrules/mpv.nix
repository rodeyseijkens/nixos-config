{...}: {
  wayland.windowManager.hyprland.settings.windowrule = [
    "float true, match:class ^(.*mpv.*)$"
    "center true, match:class ^(.*mpv.*)$"
    "size 1200 725, match:class ^(.*mpv.*)$"
    "idle_inhibit focus, match:class ^(.*mpv.*)$"
    "opacity 1.0 override 1.0 override, match:title ^(.*mpv.*)$"
    "idle_inhibit focus, match:class ^(mpv)$"
  ];
}
