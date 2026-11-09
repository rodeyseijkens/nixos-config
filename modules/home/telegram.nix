{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.telegram;
in {
  options.modules.telegram = {enable = mkEnableOption "telegram";};
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      telegram-desktop
    ];
  };
}
