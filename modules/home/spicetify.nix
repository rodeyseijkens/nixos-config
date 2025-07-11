{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
  cfg = config.modules.spicetify;
in {
  options.modules.spicetify = {enable = mkEnableOption "spicetify";};
  imports = [inputs.spicetify-nix.homeManagerModules.default];
  config = mkIf cfg.enable {
    programs.spicetify = {
      enable = true;
      enabledExtensions = with spicePkgs.extensions; [
        adblock
        hidePodcasts
        shuffle # shuffle+ (special characters are sanitized out of extension names)
      ];
    };
  };
}
