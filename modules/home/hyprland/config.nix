{
  lib,
  config,
  options,
  ...
}: let
  # Color helper functions
  rgb = color: "rgb(${color})";
  rgba = color: alpha: "rgba(${color}${alpha})";

  # Simple fallback configuration
  defaultMonitorConfig = {
    monitors = ''
      monitor = , preferred, auto, 1
    '';
    workspaces = [
      "1, default:true"
      "2"
      "3"
      "4"
      "5"
      "9"
      "10"
    ];
    windowrules = [
      "workspace 9, match:class ^(spotify)$"
      "workspace 9, match:class ^(steam)$"
      "workspace 10, match:class ^(discord|legcord)$"

      # Keyring Dialog on workspace 1
      "workspace 1, match:title ^(keyring)$"
    ];
  };

  # Use custom config if provided, otherwise fallback to default
  monitorConfig =
    if config.monitors.hyprland.enable
    then {
      monitors = config.monitors.hyprland.config;
      workspaces = config.monitors.hyprland.workspaces;
      windowrules = config.monitors.hyprland.windowrules;
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

    windowrules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Window rules (Hyprland) to apply per-host. If empty, fallback defaults are used.";
      example = [
        "workspace 9, match:class ^(spotify)$"
        "workspace 10, match:class ^(discord|legcord)$"
      ];
    };
  };

  config = {
    wayland.windowManager.hyprland = {
      settings = {
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

        cursor = {
          inactive_timeout = 5;
        };

        # workspace
        workspace = monitorConfig.workspaces;

        # workspace window rules
        windowrule = defaultMonitorConfig.windowrules ++ monitorConfig.windowrules;
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
