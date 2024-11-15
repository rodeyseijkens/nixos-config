{ pkgs, ... }: 
{
  home.packages = with pkgs; [
    webcord-vencord
  ];
  xdg.configFile."WebCord/themes/gruvbox.theme.css".source = ./gruvbox.css;
}
