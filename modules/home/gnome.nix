{pkgs, ...}: {
  home.packages = with pkgs; [
    evince # pdf
    file-roller # archive
    gnome-text-editor # gedit
    baobab # disk usage analyzer
  ];

  dconf.settings = {
    "org/gnome/TextEditor" = {
      highlight-current-line = true;
      indent-style = "space";
      restore-session = false;
      show-grid = false;
      show-line-numbers = true;
      show-right-margin = false;
      tab-width = "uint32 4";
      wrap-text = false;
    };
  };
}
