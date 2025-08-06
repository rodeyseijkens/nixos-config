{
  lib,
  config,
  options,
  ...
}: let
  browser = "zen-beta";
  terminal = "kitty";

  # Color helper functions
  rgb = color: "rgb(${color})";
  rgba = color: alpha: "rgba(${color}${alpha})";

  # Simple fallback configuration
  defaultMonitorConfig = {
    monitors = ''
      monitor = , preferred, auto, 1
    '';
    workspaces = [
      "1,   default"
      "2,   default"
      "3,   default"
      "4,   default"
      "5,   default"
      "9,   default"
      "10,  default"
    ];
  };

  # Use custom config if provided, otherwise fallback to default
  monitorConfig =
    if config.monitors.hyprland.enable
    then {
      monitors = config.monitors.hyprland.config;
      workspaces = config.monitors.hyprland.workspaces;
    }
    else defaultMonitorConfig;
in {
  imports = [./windowrules];

  # Define options for monitor configuration
  options.monitors.hyprland = {
    enable = lib.mkEnableOption "custom monitor configuration";

    config = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Monitor configuration string for Hyprland";
      example = ''
        monitor = DP-2, 2560x1440@165, -2560x0, 1
        monitor = DP-3, 2560x1440@165, 0x0, 1
      '';
    };

    workspaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Workspace to monitor assignments";
      example = [
        "1, monitor:DP-3"
        "2, monitor:DP-3"
      ];
    };
  };

  config = {
    wayland.windowManager.hyprland = {
      settings = {
        # autostart
        exec-once = [
          "wl-paste --type text --watch cliphist store" # Saves text
          "wl-paste --type image --watch cliphist store" # Saves images
          "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
"
          "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "systemctl --user start hyprpolkitagent"

          "killall -q swww;sleep .5 && swww-daemon"
          "killall -q waybar;sleep .5 && waybar"
          "killall -q swaync;sleep .5 && swaync"

          "nm-applet --indicator"
          "poweralertd"

          "hyprlock"
        ];

        input = {
          kb_layout = "us";
          kb_options = "grp:alt_caps_toggle";
          numlock_by_default = true;
          follow_mouse = 0;
          float_switch_override_focus = 0;
          mouse_refocus = 0;
          accel_profile = "flat";
          sensitivity = 0.8; # -1.0 - 1.0, 0 means no modification.
          force_no_accel = 0;
          touchpad = {
            natural_scroll = true;
          };
        };

        general = lib.mkForce {
          "$mainMod" = "SUPER";
          layout = "dwindle";
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          no_border_on_floating = false;
          "col.active_border" = rgba config.lib.stylix.colors.base0B "FF";
          "col.inactive_border" = rgba config.lib.stylix.colors.base0B "00";
        };

        misc = {
          font_family = "Maple Mono";
          disable_autoreload = true;
          disable_hyprland_logo = true;
          always_follow_on_dnd = true;
          layers_hog_keyboard_focus = true;
          animate_manual_resizes = false;
          enable_swallow = true;
          focus_on_activate = true;
          new_window_takes_over_fullscreen = 2;
          middle_click_paste = false;
        };

        dwindle = {
          force_split = 0;
          special_scale_factor = 1.0;
          split_width_multiplier = 1.0;
          use_active_for_splits = true;
          pseudotile = "yes";
          preserve_split = "yes";
        };

        master = {
          new_status = "master";
          special_scale_factor = 1;
        };

        decoration = {
          rounding = 0;

          blur = {
            enabled = true;
            size = 2;
            passes = 2;
            brightness = 1;
            contrast = 1.400;
            ignore_opacity = true;
            noise = 0;
            new_optimizations = true;
            xray = true;
            popups = true;
          };

          shadow = lib.mkForce {
            enabled = true;
            range = 20;
            render_power = 3;
            ignore_window = true;
            offset = "0 2";
            color = rgba config.lib.stylix.colors.base00 "55";
          };
        };

        animations = {
          enabled = true;

          bezier = [
            "fluent_decel,  0,    0.2,  0.4,  1"
            "easeOutCirc,   0,    0.55, 0.45, 1"
            "easeOutCubic,  0.33, 1,    0.68, 1"
            "fade_curve,    0,    0.55, 0.45, 1"
          ];

          animation = [
            # name, enable, speed, curve, style

            # Windows
            "windowsIn,   0, 4, easeOutCubic, popin 20%" # window open
            "windowsOut,  0, 4, fluent_decel, popin 80%" # window close.
            "windowsMove, 1, 2, fluent_decel, slide" # everything in between, moving, dragging, resizing.

            # Fade
            "fadeIn,      1, 3,   fade_curve" # fade in (open) -> layers and windows
            "fadeOut,     1, 3,   fade_curve" # fade out (close) -> layers and windows
            "fadeSwitch,  0, 1,   easeOutCirc" # fade on changing activewindow and its opacity
            "fadeShadow,  1, 10,  easeOutCirc" # fade on changing activewindow for shadows
            "fadeDim,     1, 4,   fluent_decel" # the easing of the dimming of inactive windows
            "workspaces,  1, 4,   easeOutCubic, fade" # styles: slide, slidevert, fade, slidefade, slidefadevert
          ];
        };

        group = {
          groupbar = lib.mkForce {
            "col.active" = rgba config.lib.stylix.colors.base00 "FF";
            "col.inactive" = rgba config.lib.stylix.colors.base00 "55";
          };
        };

        bind = [
          # show keybinds list
          "$mainMod,  F1, exec, keybinds"

          # keybindings
          "$mainMod,        Return, exec,       [float; center; size 50% 50%] ${terminal}"
          "$mainMod SHIFT,  Return, exec,       ${terminal}"
          "$mainMod ALT,    Return, exec,       [fullscreen] ${terminal}"
          "$mainMod,        B,      exec,       ${browser}"
          "$mainMod,        Q,      killactive,"
          "$mainMod,        F,      fullscreen, 0"
          "$mainMod SHIFT,  F,      fullscreen, 1"
          "$mainMod,        G,      exec,       toggle-float"
          "$mainMod,        Space,  exec,       rofi-launcher"
          "$mainMod SHIFT,  D,      exec,       legcord --enable-features=UseOzonePlatform --ozone-platform=wayland"
          "$mainMod SHIFT,  Escape, exec,       rofi-power-menu"
          "$mainMod,        P,      pseudo,"
          "$mainMod,        X,      togglesplit,"
          "$mainMod,        T,      exec,       toggle-opacity"
          "$mainMod,        E,      exec,       nautilus"
          "$mainMod SHIFT,  B,      exec,       toggle-waybar"
          "$mainMod,        C,      exec,       hyprpicker -a"
          "$mainMod,        W,      exec,       wallpaper-picker"
          "$mainMod,        N,      exec,       swaync-client -t -sw"
          "$mainMod SHIFT,  W,      exec,       vm-start"

          # screenshot
          ",                Print,  exec, rofi-screenshot-menu"
          "$mainMod,        Print,  exec, screenshot --save"
          "$mainMod SHIFT,  Print,  exec, screenshot --swappy"

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
          "$mainMod SHIFT,  T,      togglegroup" # toggle tabbed group
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

        # workspace
        workspace = monitorConfig.workspaces;

        # workspace window rules
        windowrule = [
          "workspace 5,   class:(dota2),title:(Dota 2)"
          "workspace 9,   class:^(spotify)$"
          "workspace 9,   class:^(steam)$"
          "workspace 10,  class:^(discord|legcord)$"
        ];
      };

      extraConfig = "
      ${monitorConfig.monitors}

      xwayland {
        force_zero_scaling = true
      }

      # Special Keybind disabler
      bind = $mainMod SHIFT CTRL, HOME, submap, clean
      submap = clean
      bind = $mainMod SHIFT CTRL, Q, killactive,
      bind = $mainMod SHIFT CTRL, HOME, submap, reset
      submap = reset
    ";
    };
  };
}
