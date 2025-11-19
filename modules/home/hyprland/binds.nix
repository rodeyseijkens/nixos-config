{...}: let
  browser = "zen-beta";
  terminal = "ghostty";
  filebrowser = "nautilus";
in {
  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        # applications
        "$mainMod,        Return, exec,       [float; center; size (monitor_w*0.5) (monitor_h*0.5)] ${terminal}"
        "$mainMod SHIFT,  Return, exec,       ${terminal}"
        "$mainMod ALT,    Return, exec,       [fullscreen] ${terminal}"
        "$mainMod,        B,      exec,       ${browser}"
        "$mainMod,        E,      exec,       ${filebrowser}"
        "$mainMod SHIFT,  D,      exec,       legcord & steam"

        # window management
        "$mainMod,        Q,      killactive,"
        "$mainMod,        F,      fullscreen, 0"
        "$mainMod SHIFT,  F,      fullscreen, 1"
        "$mainMod SHIFT,  T,      exec,       toggle-float"
        "$mainMod,        P,      pseudo,"
        "$mainMod,        X,      togglesplit,"
        "$mainMod,        O,      exec,       toggle-opacity"

        # utilities and scripts
        "$mainMod SHIFT,  B,      exec,       toggle-waybar"
        "$mainMod,        C,      exec,       hyprpicker -a"
        "$mainMod,        N,      exec,       swaync-client -t -sw"
        "$mainMod,        Space,  exec,       walker"
        "$mainMod SHIFT,  Escape, exec,       walker-menu power"
        "$mainMod,        W,      exec,       walker-menu wallpapers"

        # screenshot
        ",                Print,  exec, walker-menu screenshot"
        "$mainMod,        Print,  exec, screenshot --save"
        "$mainMod SHIFT,  Print,  exec, screenshot --satty"

        # switch focus
        "$mainMod,  left,   movefocus,  l"
        "$mainMod,  right,  movefocus,  r"
        "$mainMod,  up,     movefocus,  u"
        "$mainMod,  down,   movefocus,  d"
        "$mainMod,  h,      movefocus,  l"
        "$mainMod,  j,      movefocus,  d"
        "$mainMod,  k,      movefocus,  u"
        "$mainMod,  l,      movefocus,  r"

        # switch workspace
        "$mainMod,  1,  workspace,  1"
        "$mainMod,  2,  workspace,  2"
        "$mainMod,  3,  workspace,  3"
        "$mainMod,  4,  workspace,  4"
        "$mainMod,  5,  workspace,  5"
        "$mainMod,  6,  workspace,  6"
        "$mainMod,  7,  workspace,  7"
        "$mainMod,  8,  workspace,  8"
        "$mainMod,  9,  workspace,  9"
        "$mainMod,  0,  workspace,  10"

        # same as above, but move to the workspace
        "$mainMod SHIFT,  1,  movetoworkspacesilent,  1" # movetoworkspacesilent
        "$mainMod SHIFT,  2,  movetoworkspacesilent,  2"
        "$mainMod SHIFT,  3,  movetoworkspacesilent,  3"
        "$mainMod SHIFT,  4,  movetoworkspacesilent,  4"
        "$mainMod SHIFT,  5,  movetoworkspacesilent,  5"
        "$mainMod SHIFT,  6,  movetoworkspacesilent,  6"
        "$mainMod SHIFT,  7,  movetoworkspacesilent,  7"
        "$mainMod SHIFT,  8,  movetoworkspacesilent,  8"
        "$mainMod SHIFT,  9,  movetoworkspacesilent,  9"
        "$mainMod SHIFT,  0,  movetoworkspacesilent,  10"
        "$mainMod CTRL,   c,  movetoworkspace,        empty"

        # window control
        "$mainMod SHIFT,  left,   movewindoworgroup,  l"
        "$mainMod SHIFT,  right,  movewindoworgroup,  r"
        "$mainMod SHIFT,  up,     movewindoworgroup,  u"
        "$mainMod SHIFT,  down,   movewindoworgroup,  d"
        "$mainMod SHIFT,  h,      movewindoworgroup,  l"
        "$mainMod SHIFT,  j,      movewindoworgroup,  d"
        "$mainMod SHIFT,  k,      movewindoworgroup,  u"
        "$mainMod SHIFT,  l,      movewindoworgroup,  r"

        "$mainMod CTRL, left,   resizeactive, -80 0"
        "$mainMod CTRL, right,  resizeactive, 80 0"
        "$mainMod CTRL, up,     resizeactive, 0 -80"
        "$mainMod CTRL, down,   resizeactive, 0 80"
        "$mainMod CTRL, h,      resizeactive, -80 0"
        "$mainMod CTRL, j,      resizeactive, 0 80"
        "$mainMod CTRL, k,      resizeactive, 0 -80"
        "$mainMod CTRL, l,      resizeactive, 80 0"

        "$mainMod ALT,  left,   moveactive, -80 0"
        "$mainMod ALT,  right,  moveactive, 80 0"
        "$mainMod ALT,  up,     moveactive, 0 -80"
        "$mainMod ALT,  down,   moveactive, 0 80"
        "$mainMod ALT,  h,      moveactive, -80 0"
        "$mainMod ALT,  j,      moveactive, 0 80"
        "$mainMod ALT,  k,      moveactive, 0 -80"
        "$mainMod ALT,  l,      moveactive, 80 0"

        # window tabbed grouping
        "$mainMod SHIFT,  G,      togglegroup" # toggle tabbed group
        "$mainMod ALT,    left,   changegroupactive,  b" # change active tab back
        "$mainMod ALT,    right,  changegroupactive,  f" # change active tab forward
        "$mainMod ALT,    j,      changegroupactive,  b" # change active tab back
        "$mainMod ALT,    l,      changegroupactive,  f" # change active tab forward

        # media and volume controls
        # ",XF86AudioMute,exec, pamixer -t"
        ",XF86AudioPlay,  exec, playerctl play-pause"
        ",XF86AudioNext,  exec, playerctl next"
        ",XF86AudioPrev,  exec, playerctl previous"
        ",XF86AudioStop,  exec, playerctl stop"

        "$mainMod,  mouse_down, workspace, e-1"
        "$mainMod,  mouse_up, workspace, e+1"
      ];

      # # binds active in lockscreen
      # bindl = [
      #   # laptop brigthness
      #   ",XF86MonBrightnessUp, exec, brightnessctl set 5%+"
      #   ",XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      #   "$mainMod, XF86MonBrightnessUp, exec, brightnessctl set 100%+"
      #   "$mainMod, XF86MonBrightnessDown, exec, brightnessctl set 100%-"
      # ];

      # # binds that repeat when held
      # binde = [
      #   ",XF86AudioRaiseVolume,exec, pamixer -i 2"
      #   ",XF86AudioLowerVolume,exec, pamixer -d 2"
      # ];

      # mouse binding
      bindm = [
        "$mainMod,        mouse:274,  movewindow"
        "$mainMod SHIFT,  mouse:274,  resizewindow"
      ];
    };
  };
}
