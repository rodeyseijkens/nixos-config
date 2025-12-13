{...}: let
  terminal = "ghostty";
in {
  wayland.windowManager.hyprland = {
    settings = {
      # autostart
      exec-once = [
        "wl-paste --type text --watch cliphist store" # Saves text
        "wl-paste --type image --watch cliphist store" # Saves images
        "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "systemctl --user start hyprpolkitagent"

        "killall -q waybar;sleep .5 && waybar"
        "killall -q swaync;sleep .5 && swaync"
        "killall -q elephant;sleep .5 && elephant"
        "killall -q walker;sleep .5 && walker --gapplication-service"
        "killall -q swww;sleep .5 && swww-daemon"

        "nm-applet --indicator"
        "poweralertd"

        "hyprlock"

        "${terminal} --gtk-single-instance=true --quit-after-last-window-closed=false --initial-window=false"
      ];
    };
  };
}
