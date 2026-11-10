{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.quickshell;
  mkEntry = entry:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/quickshell/config/${entry}";
in {
  options.modules.quickshell = {
    enable =
      lib.mkEnableOption "Quickshell shell (bar, media, notifications, OSD, lock)"
      // {default = true;};
  };

  config = lib.mkIf cfg.enable {
    programs.quickshell = {
      enable = true;
      # Config lives at ~/.config/quickshell/shell/ → named config "shell".
      # Must match the `qs -c shell ipc call …` binds in hyprland/binds.nix.
      activeConfig = "shell";
      systemd = {
        enable = true;
        target = "hyprland-session.target";
      };
    };

    systemd.user.services.quickshell-lock-on-session = {
      Unit = {
        Description = "Lock the session after Hyprland starts";
        # Ordering after quickshell.service would create a cycle:
        # quickshell.service is ordered After hyprland-session.target, which
        # itself starts this unit. The script below waits for the IPC instead.
      };
      Service = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "quickshell-lock-on-session" ''
          runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
          stamp="$runtime_dir/quickshell-session-locked"
          [ -e "$stamp" ] && exit 0
          for attempt in $(seq 1 100); do
            if ${pkgs.quickshell}/bin/qs -c shell ipc call lock lock; then
              touch "$stamp"
              exit 0
            fi
            sleep 0.1
          done
          touch "$stamp"
          exec ${pkgs.hyprlock}/bin/hyprlock
        '';
        RemainAfterExit = true;
      };
      Install.WantedBy = ["hyprland-session.target"];
    };

    home.packages = with pkgs; [
      brightnessctl
      cava
      pamixer
      pulseaudio
      pwvucontrol

      (writeShellApplication {
        name = "weather-location";
        runtimeInputs = [jq coreutils];
        text = ''
          state="$HOME/.local/state/quickshell/settings/weather.json"
          case "''${1:-}" in
            --clear)
              rm -f "$state"
              ;;
            --set)
              name="''${2:-}"
              coords="''${3:-}"
              [ -z "$name" ] && exit 1
              mkdir -p "$(dirname "$state")"
              if [ -n "$coords" ]; then
                lat="''${coords%%,*}"
                lon="''${coords#*,}"
                jq -n --arg name "$name" --argjson lat "$lat" --argjson lon "$lon" \
                  '{name:$name, latitude:$lat, longitude:$lon}' > "$state"
              else
                jq -n --arg name "$name" \
                  '{name:$name, latitude:null, longitude:null}' > "$state"
              fi
              ;;
            *)
              exit 1
              ;;
          esac
        '';
      })
    ];

    xdg.configFile."quickshell/shell/shell.qml".source = mkEntry "shell.qml";
    xdg.configFile."quickshell/shell/qmldir".source = mkEntry "qmldir";
    xdg.configFile."quickshell/shell/plugins".source = mkEntry "plugins";
    xdg.configFile."quickshell/shell/services".source = mkEntry "services";
    xdg.configFile."quickshell/shell/Commons".source = mkEntry "Commons";
    xdg.configFile."quickshell/shell/Ui".source = mkEntry "Ui";

    xdg.configFile."quickshell/shell/Colors.qml".text = import ./tokens.nix {
      colors = config.lib.stylix.colors;
    };

    xdg.configFile."quickshell/shell/.qmlls.ini" = {
      force = true;
      text = ''
        [General]
        importPaths=${pkgs.quickshell}/lib/qt-6/qml
      '';
    };
  };
}
