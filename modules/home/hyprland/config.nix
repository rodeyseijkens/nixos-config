{
  lib,
  config,
  options,
  ...
}: let
  inherit (import ./hyprland-util.nix { inherit lib; }) bind exec killactive submap;

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
      {
        match.class = "^(spotify)$";
        workspace = "8";
      }
      {
        match.class = "^(steam)$";
        workspace = "9";
      }
      {
        match.class = "^(legcord)$";
        workspace = "10";
      }
      {
        match.title = "(?i).*keyring.*";
        workspace = "1";
      }
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

  # Split monitor lines and strip "monitor = " prefix for Lua config
  parseMonitorLines = lines: let
    individual = builtins.filter (s: s != "") (lib.splitString "\n" lines);
  in
    map (line: lib.removePrefix "monitor = " line) individual;
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
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = "Window rules (Hyprland Lua format) to apply per-host.";
      example = [
        {
          match.class = "(?i)spotify";
          workspace = "8";
        }
        {
          match.class = "^(legcord)$";
          workspace = "10";
        }
      ];
    };
  };

  config = {
    wayland.windowManager.hyprland = {
      configType = "lua";

      settings = {
        monitor = parseMonitorLines monitorConfig.monitors;

        config = {
          input = {
            kb_layout = "us";
            kb_options = "grp:alt_caps_toggle";
            numlock_by_default = true;
            follow_mouse = 0;
            float_switch_override_focus = 0;
            mouse_refocus = false;
            accel_profile = "flat";
            sensitivity = 0.8; # -1.0 - 1.0, 0 means no modification.
            force_no_accel = false;
            touchpad = {
              natural_scroll = true;
            };
          };

          general = lib.mkForce {
            layout = "dwindle";
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            "col.active_border" = rgba config.lib.stylix.colors.base0D "FF";
            "col.inactive_border" = rgba config.lib.stylix.colors.base0D "00";
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
            middle_click_paste = false;
          };

          dwindle = {
            force_split = 2;
            special_scale_factor = 1.0;
            split_width_multiplier = 1.0;
            use_active_for_splits = true;
            preserve_split = true;
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
              "windowsIn,   0, 4, easeOutCubic, popin 20%"
              "windowsOut,  0, 4, fluent_decel, popin 80%"
              "windowsMove, 1, 2, fluent_decel, slide"
              "fadeIn,      1, 3,   fade_curve"
              "fadeOut,     1, 3,   fade_curve"
              "fadeSwitch,  0, 1,   easeOutCirc"
              "fadeShadow,  1, 10,  easeOutCirc"
              "fadeDim,     1, 4,   fluent_decel"
              "workspaces,  1, 4,   easeOutCubic, fade"
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
            no_hardware_cursors = true;
          };

          # workspace
          workspace = monitorConfig.workspaces;

          xwayland = {
            force_zero_scaling = true;
          };
        };

        # workspace window rules (Lua format)
        window_rule = defaultMonitorConfig.windowrules ++ monitorConfig.windowrules;

        # Clean submap (converted from extraConfig)
        bind = [
          (bind "SUPER SHIFT CTRL, HOME" (submap "clean"))
          (bind "SUPER SHIFT CTRL, Q" killactive)
          (bind "SUPER SHIFT CTRL, Escape" (submap "reset"))
        ];
      };
    };
  };
}