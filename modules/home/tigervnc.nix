{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.tigervnc;
in {
  options.modules.tigervnc = {enable = mkEnableOption "tigervnc";};
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      tigervnc
    ];
  };
}
