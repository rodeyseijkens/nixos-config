{
  pkgs,
  config,
  lib,
  ...
}: {
  gtk = {
    enable = true;
    # font = {
    #   name = "Maple Mono";
    #   size = 12;
    # };
    theme = lib.mkForce {
      name = "Colloid-Green-Dark-Gruvbox";
      package = pkgs.colloid-gtk-theme.override {
        colorVariants = ["dark"];
        themeVariants = ["green"];
        tweaks = ["gruvbox" "rimless" "float"];
      };
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.theme = config.gtk.theme;
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };
}
