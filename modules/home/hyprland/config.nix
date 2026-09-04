{
  lib,
  config,
  options,
  ...
}: let
  inherit (import ./hyprland-util.nix { inherit lib; }) bind exec closeactive submap curve;

  # Color helper functions
  rgb = color: "rgb(${color})";
  rgba = color: alpha: "rgba(${color}${alpha})";

  # Simple fallback configuration
  defaultMonitorConfig = {
    monitors = ''
      monitor = , preferred, auto, 1
    '';
    workspaces = [
      {
        workspace = "1";
        default = true;
      }
      {
        workspace = "2";
      }
      {
        workspace = "3";
      }
      {
        workspace = "4";
      }
      {
        workspace = "5";
      }
      {
        workspace = "9";
      }
      {
        workspace = "10";
      }
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

  # Parse old-style monitor lines into the Lua hl.monitor table format.
  # Input (hyprlang):  monitor = DP-2, 2560x1440@165, -2560x0, 1
  # Output (Lua):      { output = "DP-2"; mode = "2560x1440@165"; position = "-2560x0"; scale = 1; }
  parseMonitorLines = lines: let
    individual = builtins.filter (s: s != "") (lib.splitString "\n" lines);
    # Strip the "monitor = " prefix
    stripped = map (line: lib.removePrefix "monitor = " line) individual;
    # Split a monitor line on commas, respecting position like "-2560x0"
    # and optional key/value pairs (transform, vrr, disabled, ...)
    parseLine = line: let
      parts = map lib.trim (lib.splitString "," line);
      head = builtins.head parts;
      rest = builtins.tail parts;
      base = {
        output = head;
        mode = getNth 0 rest;
        position = getNth 1 rest;
        scale = getNth 2 rest;
      } // (parseOptionalMonitorArgs (lib.drop 3 rest));
      # Safely get the nth element or null if out of bounds.
      getNth = n: xs:
        if builtins.length xs > n then builtins.elemAt xs n else null;
    in
      lib.filterAttrs (_: v: v != null) base;
  in
    map parseLine stripped;

  # Parse optional monitor args (e.g. "transform, 3" / "vrr, 1" / "disabled") into fields.
  parseOptionalMonitorArgs = args: let
    go = acc: xs:
      if builtins.length xs == 0 then acc
      else
        let
          key = builtins.elemAt xs 0;
          hasVal = builtins.length xs >= 2;
          val =
            if hasVal
            then builtins.fromJSON (builtins.elemAt xs 1)
            else true;
          remaining =
            if hasVal then lib.drop 2 xs else lib.drop 1 xs;
        in go (acc // { ${key} = val; }) remaining;
  in
    go {} args;
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
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = "Workspace to monitor assignments (Hyprland Lua workspace_rule format).";
      example = [
        {
          workspace = "1";
          monitor = "DP-3";
          default = true;
        }
        {
          workspace = "2";
          monitor = "DP-3";
        }
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

          xwayland = {
            force_zero_scaling = true;
          };
        };

        # workspace to monitor assignments (Lua hl.workspace_rule format)
        workspace_rule = monitorConfig.workspaces;

        # workspace window rules (Lua format)
        window_rule = defaultMonitorConfig.windowrules ++ monitorConfig.windowrules;

        # Bezier curves (hl.curve) — must precede the hl.animation calls below.
        curve = [
          (curve "fluent_decel" {
            type = "bezier";
            points = [
              [0 0.2]
              [0.4 1]
            ];
          })
          (curve "easeOutCirc" {
            type = "bezier";
            points = [
              [0 0.55]
              [0.45 1]
            ];
          })
          (curve "easeOutCubic" {
            type = "bezier";
            points = [
              [0.33 1]
              [0.68 1]
            ];
          })
          (curve "fade_curve" {
            type = "bezier";
            points = [
              [0 0.55]
              [0.45 1]
            ];
          })
        ];

        # Animation leaves (hl.animation) restoring the previous config.
        animation = [
          {
            leaf = "windowsIn";
            enabled = false;
            speed = 4;
            bezier = "easeOutCubic";
            style = "popin 20%";
          }
          {
            leaf = "windowsOut";
            enabled = false;
            speed = 4;
            bezier = "fluent_decel";
            style = "popin 80%";
          }
          {
            leaf = "windowsMove";
            enabled = true;
            speed = 2;
            bezier = "fluent_decel";
            style = "slide";
          }
          {
            leaf = "fadeIn";
            enabled = true;
            speed = 3;
            bezier = "fade_curve";
          }
          {
            leaf = "fadeOut";
            enabled = true;
            speed = 3;
            bezier = "fade_curve";
          }
          {
            leaf = "fadeSwitch";
            enabled = false;
            speed = 1;
            bezier = "easeOutCirc";
          }
          {
            leaf = "fadeShadow";
            enabled = true;
            speed = 10;
            bezier = "easeOutCirc";
          }
          {
            leaf = "fadeDim";
            enabled = true;
            speed = 4;
            bezier = "fluent_decel";
          }
          {
            leaf = "workspaces";
            enabled = true;
            speed = 4;
            bezier = "easeOutCubic";
            style = "fade";
          }
        ];

        # Enter the "clean" submap from the global keymap (toggle — see submaps).
        bind = [
          (bind "SUPER SHIFT CTRL, HOME" (submap "clean"))
        ];
      };

      # Clean submap (Special Keybind disabler). Entering it deactivates all
      # global binds; the binds below are only active while the clean submap
      # is active and are registered via hl.define_submap.
      submaps = {
        clean = {
          settings = {
            bind = [
              (bind "SUPER SHIFT CTRL, HOME" (submap "reset"))
              (bind "SUPER SHIFT CTRL, Q" closeactive)
            ];
          };
        };
      };
    };
  };
}
