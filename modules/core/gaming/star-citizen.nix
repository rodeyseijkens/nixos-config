{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
with lib; let
  cfg = config.core.star-citizen;
in {
  options.core.star-citizen = {
    enable = mkEnableOption "Enable Star Citizen";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      inputs.nix-citizen.packages.${pkgs.system}.star-citizen
    ];
    boot.kernel.sysctl = {
      "fs.file-max" = 524288;
    };
  };
}
