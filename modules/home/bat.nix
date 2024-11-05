{ pkgs, ... }: 
{
  programs.bat = {
    enable = true;
    config = {
      pager = "less -NL";
      theme = "gruvbox-dark";
    };
    extraPackages = with pkgs.bat-extras; [
      batman
      batpipe
      batgrep
      # batdiff
    ];
  };
}
