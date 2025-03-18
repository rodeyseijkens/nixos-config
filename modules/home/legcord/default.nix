{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.legcord;
in {
  options.modules.legcord = {enable = mkEnableOption "legcord";};
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      legcord
    ];
    xdg.configFile."legcord/themes/gruvbox.theme.css".source = ./gruvbox.css;
  };
}
