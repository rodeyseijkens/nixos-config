{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.webcord;
in {
  options.modules.webcord = {enable = mkEnableOption "webcord";};
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      webcord-vencord
    ];
    xdg.configFile."WebCord/themes/gruvbox.theme.css".source = ./gruvbox.css;
  };
}
