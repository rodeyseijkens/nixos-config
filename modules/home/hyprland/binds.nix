{
  config,
  lib,
  ...
}: let
  inherit (import ./hyprland-util.nix { inherit lib; })
    bind bindFlags bindLocked bindRepeat bindLockedRepeat bindMouse
    exec execRaw killactive fullscreenToggle fullscreenMaximize
    movefocus movewindow focusWorkspace moveToWorkspace moveToWorkspaceStr
    resizeactive moveactive pseudo layoutmsg togglegroup changegroupactive
    dragWindow resizeWindow
    ;

  browser = config.modules.defaultBrowser;
  terminal = "ghostty";
  filebrowser = "nautilus";

  inherit (lib.generators) mkLuaInline;
in {
  wayland.windowManager.hyprland.settings = {
    bind = [
      # applications
      (bind "SUPER, Return" (exec "[float; center; size 50% 50%] ${terminal}"))
      (bind "SUPER SHIFT, Return" (exec "${terminal}"))
      (bind "SUPER ALT, Return" (exec "[fullscreen] ${terminal}"))
      (bind "SUPER, B" (exec "${browser}"))
      (bind "SUPER, E" (exec "${filebrowser}"))
      (bind "SUPER SHIFT, D" (exec "legcord & steam"))

      # window management
      (bind "SUPER, Q" killactive)
      (bind "SUPER, F" fullscreenToggle)
      (bind "SUPER SHIFT, F" fullscreenMaximize)
      (bind "SUPER SHIFT, T" (exec "toggle-float"))
      (bind "SUPER, P" pseudo)
      (bind "SUPER, X" (layoutmsg "togglesplit"))
      (bind "SUPER, O" (exec "toggle-opacity"))

      # utilities and scripts
      (bind "SUPER SHIFT, W" (exec "toggle-waybar"))
      (bind "SUPER, C" (exec "hyprpicker -a"))
      (bind "SUPER, N" (exec "swaync-client -t -sw"))
      (bind "SUPER, Space" (exec "walker-menu apps"))

      (bind "SUPER, period" (execRaw "sh -c 'pkill -USR2 -x handy || pkill -USR2 -x .handy-wrapped'"))
      (bind "SUPER CTRL, Space" (exec "walker-menu"))
      (bind "SUPER SHIFT, Escape" (exec "walker-menu power"))
      (bind "SUPER, W" (exec "walker-menu wallpapers"))
      (bind "SUPER, R" (exec "walker-menu projects"))

      # screenshot and recording
      (bind ", Print" (exec "walker-menu screenshot"))
      (bind "SUPER, Print" (exec "screenshot copy-output"))
      (bind "SUPER SHIFT, Print" (exec "screenshot edit-output"))
      (bind "ALT, Print" (execRaw "sh -c 'pgrep -x wf-recorder >/dev/null && record stop || walker-menu record'"))

      # switch focus
      (bind "SUPER, left" (movefocus "l"))
      (bind "SUPER, right" (movefocus "r"))
      (bind "SUPER, up" (movefocus "u"))
      (bind "SUPER, down" (movefocus "d"))
      (bind "SUPER, h" (movefocus "l"))
      (bind "SUPER, j" (movefocus "d"))
      (bind "SUPER, k" (movefocus "u"))
      (bind "SUPER, l" (movefocus "r"))

      # switch workspace
      (bind "SUPER, 1" (focusWorkspace 1))
      (bind "SUPER, 2" (focusWorkspace 2))
      (bind "SUPER, 3" (focusWorkspace 3))
      (bind "SUPER, 4" (focusWorkspace 4))
      (bind "SUPER, 5" (focusWorkspace 5))
      (bind "SUPER, 6" (focusWorkspace 6))
      (bind "SUPER, 7" (focusWorkspace 7))
      (bind "SUPER, 8" (focusWorkspace 8))
      (bind "SUPER, 9" (focusWorkspace 9))
      (bind "SUPER, 0" (focusWorkspace 10))

      (bind "SUPER SHIFT, 1" (moveToWorkspace 1))
      (bind "SUPER SHIFT, 2" (moveToWorkspace 2))
      (bind "SUPER SHIFT, 3" (moveToWorkspace 3))
      (bind "SUPER SHIFT, 4" (moveToWorkspace 4))
      (bind "SUPER SHIFT, 5" (moveToWorkspace 5))
      (bind "SUPER SHIFT, 6" (moveToWorkspace 6))
      (bind "SUPER SHIFT, 7" (moveToWorkspace 7))
      (bind "SUPER SHIFT, 8" (moveToWorkspace 8))
      (bind "SUPER SHIFT, 9" (moveToWorkspace 9))
      (bind "SUPER SHIFT, 0" (moveToWorkspace 10))
      (bind "SUPER CTRL, c" (moveToWorkspaceStr "empty"))

      # window movement
      (bind "SUPER SHIFT, left" (movewindow "l"))
      (bind "SUPER SHIFT, right" (movewindow "r"))
      (bind "SUPER SHIFT, up" (movewindow "u"))
      (bind "SUPER SHIFT, down" (movewindow "d"))
      (bind "SUPER SHIFT, h" (movewindow "l"))
      (bind "SUPER SHIFT, j" (movewindow "d"))
      (bind "SUPER SHIFT, k" (movewindow "u"))
      (bind "SUPER SHIFT, l" (movewindow "r"))

      # resize active window
      (bind "SUPER CTRL, left" (resizeactive (-80) 0))
      (bind "SUPER CTRL, right" (resizeactive 80 0))
      (bind "SUPER CTRL, up" (resizeactive 0 (-80)))
      (bind "SUPER CTRL, down" (resizeactive 0 80))
      (bind "SUPER CTRL, h" (resizeactive (-80) 0))
      (bind "SUPER CTRL, j" (resizeactive 0 80))
      (bind "SUPER CTRL, k" (resizeactive 0 (-80)))
      (bind "SUPER CTRL, l" (resizeactive 80 0))

      # move active window (not changing workspace)
      (bind "SUPER ALT, left" (moveactive (-80) 0))
      (bind "SUPER ALT, right" (moveactive 80 0))
      (bind "SUPER ALT, up" (moveactive 0 (-80)))
      (bind "SUPER ALT, down" (moveactive 0 80))
      (bind "SUPER ALT, h" (moveactive (-80) 0))
      (bind "SUPER ALT, j" (moveactive 0 80))
      (bind "SUPER ALT, k" (moveactive 0 (-80)))
      (bind "SUPER ALT, l" (moveactive 80 0))

      # window tabbed grouping
      (bind "SUPER SHIFT, G" togglegroup)
      (bind "SUPER ALT, left" (changegroupactive "b"))
      (bind "SUPER ALT, right" (changegroupactive "f"))
      (bind "SUPER ALT, h" (changegroupactive "b"))
      (bind "SUPER ALT, l" (changegroupactive "f"))

      # media and volume controls
      (bind ", XF86AudioPlay" (exec "playerctl play-pause"))
      (bind ", XF86AudioNext" (exec "playerctl next"))
      (bind ", XF86AudioPrev" (exec "playerctl previous"))
      (bind ", XF86AudioStop" (exec "playerctl stop"))

      # scroll through workspaces
      (bind "SUPER, mouse_down" (mkLuaInline ''hl.dsp.focus({ workspace = "e-1" })''))
      (bind "SUPER, mouse_up" (mkLuaInline ''hl.dsp.focus({ workspace = "e+1" })''))

      # mouse bindings
      (bindMouse "SUPER, mouse:274" dragWindow)
      (bindMouse "SUPER SHIFT, mouse:274" resizeWindow)
    ]
    ++ lib.optionals (config.modules.defaultBrowser == "google-chrome") [
      (bind "SUPER SHIFT, B" (exec "zen-beta"))
    ];
  };
}