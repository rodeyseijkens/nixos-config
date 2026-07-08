{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.t3code;
in {
  options.modules.t3code = {enable = mkEnableOption "t3code";};
  config = mkIf cfg.enable {
    home.packages = [pkgs.t3code];
  };
}
