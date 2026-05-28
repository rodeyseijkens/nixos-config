{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
with lib; let
  cfg = config.core.steam;
in {
  imports = [
    inputs.nix-gaming.nixosModules.platformOptimizations
  ];

  options.core.steam = {
    enable = mkEnableOption "Enable Steam";
  };

  config = mkIf cfg.enable {
    programs = {
      steam = {
        enable = true;

        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = false;

        gamescopeSession.enable = true;

        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];

        platformOptimizations.enable = true;
      };

      gamescope = {
        enable = true;
        # Workaround for nixpkgs issue #523200 / bubblewrap 0.11.2.
        # With Steam gamescope sessions enabled, capSysNice=true makes Steam
        # try setuid bubblewrap, which now fails to start.
        capSysNice = false;
        args = [
          "--rt"
          "--expose-wayland"
        ];
      };
    };

    environment.systemPackages = with pkgs; [
      protonplus
    ];
  };
}
