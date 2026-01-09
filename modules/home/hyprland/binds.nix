{...}: let
  browser = "zen-beta";
  terminal = "ghostty";
  filebrowser = "nautilus";
in {
  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        # applications
        "$mod,        Return, exec,       [float; center; size (monitor_w*0.5) (monitor_h*0.5)] ${terminal}"
        "$mod SHIFT,  Return, exec,       ${terminal}"
        "$mod ALT,    Return, exec,       [fullscreen] ${terminal}"
        "$mod,        B,      exec,       ${browser}"
        "$mod,        E,      exec,       ${filebrowser}"
        "$mod SHIFT,  D,      exec,       legcord & steam"

        # window management
        "$mod,        Q,      killactive,"
        "$mod,        F,      fullscreen, 0"
        "$mod SHIFT,  F,      fullscreen, 1"
        "$mod SHIFT,  T,      exec,       toggle-float"
        "$mod,        P,      pseudo,"
        "$mod,        X,      togglesplit,"
        "$mod,        O,      exec,       toggle-opacity"

        # utilities and scripts
        "$mod SHIFT,  B,      exec,       toggle-waybar"
        "$mod,        C,      exec,       hyprpicker -a"
        "$mod,        N,      exec,       swaync-client -t -sw"
        "$mod,        Space,  exec,       walker-menu apps"
        "$mod CTRL,   Space,  exec,       walker-menu"
        "$mod SHIFT,  Escape, exec,       walker-menu power"
        "$mod,        W,      exec,       walker-menu wallpapers"

        # screenshot
        ",                Print,  exec, walker-menu screenshot"
        "$mod,        Print,  exec, screenshot copy-output"
        "$mod SHIFT,  Print,  exec, screenshot edit-output"

        # switch focus
        "$mod,  left,   movefocus,  l"
        "$mod,  right,  movefocus,  r"
        "$mod,  up,     movefocus,  u"
        "$mod,  down,   movefocus,  d"
        "$mod,  h,      movefocus,  l"
        "$mod,  j,      movefocus,  d"
        "$mod,  k,      movefocus,  u"
        "$mod,  l,      movefocus,  r"

        # switch workspace
        "$mod,  1,  workspace,  1"
        "$mod,  2,  workspace,  2"
        "$mod,  3,  workspace,  3"
        "$mod,  4,  workspace,  4"
        "$mod,  5,  workspace,  5"
        "$mod,  6,  workspace,  6"
        "$mod,  7,  workspace,  7"
        "$mod,  8,  workspace,  8"
        "$mod,  9,  workspace,  9"
        "$mod,  0,  workspace,  10"

        # same as above, but move to the workspace
        "$mod SHIFT,  1,  movetoworkspacesilent,  1" # movetoworkspacesilent
        "$mod SHIFT,  2,  movetoworkspacesilent,  2"
        "$mod SHIFT,  3,  movetoworkspacesilent,  3"
        "$mod SHIFT,  4,  movetoworkspacesilent,  4"
        "$mod SHIFT,  5,  movetoworkspacesilent,  5"
        "$mod SHIFT,  6,  movetoworkspacesilent,  6"
        "$mod SHIFT,  7,  movetoworkspacesilent,  7"
        "$mod SHIFT,  8,  movetoworkspacesilent,  8"
        "$mod SHIFT,  9,  movetoworkspacesilent,  9"
        "$mod SHIFT,  0,  movetoworkspacesilent,  10"
        "$mod CTRL,   c,  movetoworkspace,        empty"

        # window control
        "$mod SHIFT,  left,   movewindow,  l"
        "$mod SHIFT,  right,  movewindow,  r"
        "$mod SHIFT,  up,     movewindow,  u"
        "$mod SHIFT,  down,   movewindow,  d"
        "$mod SHIFT,  h,      movewindow,  l"
        "$mod SHIFT,  j,      movewindow,  d"
        "$mod SHIFT,  k,      movewindow,  u"
        "$mod SHIFT,  l,      movewindow,  r"

        "$mod CTRL, left,   resizeactive, -80 0"
        "$mod CTRL, right,  resizeactive, 80 0"
        "$mod CTRL, up,     resizeactive, 0 -80"
        "$mod CTRL, down,   resizeactive, 0 80"
        "$mod CTRL, h,      resizeactive, -80 0"
        "$mod CTRL, j,      resizeactive, 0 80"
        "$mod CTRL, k,      resizeactive, 0 -80"
        "$mod CTRL, l,      resizeactive, 80 0"

        "$mod ALT,  left,   moveactive, -80 0"
        "$mod ALT,  right,  moveactive, 80 0"
        "$mod ALT,  up,     moveactive, 0 -80"
        "$mod ALT,  down,   moveactive, 0 80"
        "$mod ALT,  h,      moveactive, -80 0"
        "$mod ALT,  j,      moveactive, 0 80"
        "$mod ALT,  k,      moveactive, 0 -80"
        "$mod ALT,  l,      moveactive, 80 0"

        # window tabbed grouping
        "$mod SHIFT,  G,      togglegroup" # toggle tabbed group
        "$mod ALT,    left,   changegroupactive,  b" # change active tab back
        "$mod ALT,    right,  changegroupactive,  f" # change active tab forward
        "$mod ALT,    h,      changegroupactive,  b" # change active tab back
        "$mod ALT,    l,      changegroupactive,  f" # change active tab forward

        # media and volume controls
        # ",XF86AudioMute,exec, pamixer -t"
        ",XF86AudioPlay,  exec, playerctl play-pause"
        ",XF86AudioNext,  exec, playerctl next"
        ",XF86AudioPrev,  exec, playerctl previous"
        ",XF86AudioStop,  exec, playerctl stop"

        "$mod,  mouse_down, workspace, e-1"
        "$mod,  mouse_up, workspace, e+1"
      ];

      # mouse binding
      bindm = [
        "$mod,        mouse:274,  movewindow"
        "$mod SHIFT,  mouse:274,  resizewindow"
      ];
    };
  };
}
