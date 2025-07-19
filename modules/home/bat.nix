{pkgs, ...}: {
  programs.bat = {
    enable = true;
    config = {
      pager = "less -NL";
    };
    extraPackages = with pkgs.bat-extras; [
      batman
      batpipe
      batgrep
      # batdiff
    ];
  };
}
