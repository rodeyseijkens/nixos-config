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
    # wayprompt was removed from home-manager (and nixpkgs), but stylix still
    # auto-enables its target and would define the now-removed option.
    targets.wayprompt.enable = false;
  };
}
