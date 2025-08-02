{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.audio.pipewire;
in {
  options.audio.pipewire = {
    enable = lib.mkEnableOption "audio configuration";

    cards = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          profile = lib.mkOption {
            type = lib.types.str;
            default = "off";
            description = "Audio card profile to set";
          };
        };
      });
      default = {};
      description = "Audio cards configuration";
    };

    defaultSink = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default audio sink (output device)";
    };

    defaultSource = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default audio source (input device)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create a script to apply audio configuration
    home.file.".config/scripts/audio-setup.sh" = {
      text = ''
        #!/usr/bin/env bash

        # Wait for PipeWire to be ready
        sleep 2

        # Set card profiles
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (cardName: cardConfig: ''
            pactl set-card-profile "${cardName}" "${cardConfig.profile}"
          '')
          cfg.cards)}

        # Set default sink if specified
        ${lib.optionalString (cfg.defaultSink != null) ''
          pactl set-default-sink "${cfg.defaultSink}"
        ''}

        # Set default source if specified
        ${lib.optionalString (cfg.defaultSource != null) ''
          pactl set-default-source "${cfg.defaultSource}"
        ''}
      '';
      executable = true;
    };

    # Run audio setup on login
    wayland.windowManager.hyprland.settings.exec-once = lib.mkAfter [
      "~/.config/scripts/audio-setup.sh"
    ];
  };
}
