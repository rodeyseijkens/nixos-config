{
  pkgs,
  stylix,
  ...
}: {
  stylix = {
    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      light = "Papirus-Dark";
      dark = "Papirus-Dark";
    };
    targets.zen-browser = {
      profileNames = ["default"];
    };
  };
}
