{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.walker;
in {
  options.modules.walker = {
    enable = mkEnableOption {
      default = false;
      description = "Enable Walker launcher";
    };

    runAsService = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to run Walker as a background service for faster startup";
    };
  };

  imports = [inputs.walker.homeManagerModules.default];

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      libqalculate
    ];

    programs.walker = {
      enable = true;
      package = inputs.walker.packages.${pkgs.system}.default;
      inherit (cfg) runAsService;
    };

    # Add auto-start for Hyprland if runAsService is enabled
    wayland.windowManager.hyprland.extraConfig = mkIf (cfg.runAsService && config.wayland.windowManager.hyprland.enable) ''
      exec-once=walker --gapplication-service
    '';

    # Create out-of-store symlink to the walker config.toml file
    xdg.configFile."walker/config.toml".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/walker/config.toml");
  };
}
