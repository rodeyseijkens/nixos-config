{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.obs-studio;
in {
  options.modules.obs-studio = {enable = mkEnableOption "obs-studio";};
  config = mkIf cfg.enable {
    programs.obs-studio.enable = true;
  };
}
