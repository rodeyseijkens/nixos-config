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
        capSysNice = true;
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
