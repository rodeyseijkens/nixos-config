{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.tiled;
in {
  options.modules.tiled = {enable = mkEnableOption "tiled";};
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      tiled
    ];
  };
}
