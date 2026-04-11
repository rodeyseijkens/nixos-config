{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    vimAlias = true;
    withRuby = true;
    withPython3 = true;
  };
}
