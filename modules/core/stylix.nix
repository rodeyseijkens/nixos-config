{
  pkgs,
  stylix,
  ...
}: let
  fontSize = 12;
  themeName = "gruvbox-material-dark-hard";
in {
  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";

    # base16Scheme = "${pkgs.base16-schemes}/share/themes/${themeName}.yaml";

    base16Scheme = {
      system = "base16";
      name = "Rodey Gruvb0x";
      author = "Rodey";
      variant = "dark";
      palette = {
        base00 = "#1D2021"; # ----
        base01 = "#3C3836"; # ---
        base02 = "#504945"; # --
        base03 = "#665C54"; # -
        base04 = "#BDAE93"; # +
        base05 = "#D5C4A1"; # ++
        base06 = "#EBDBB2"; # +++
        base07 = "#FBF1C7"; # ++++
        base08 = "#FB4934"; # red
        base09 = "#FE8019"; # orange
        base0A = "#D79921"; # yellow
        base0B = "#98971A"; # green
        base0C = "#689D6A"; # aqua/cyan
        base0D = "#458588"; # blue
        base0E = "#D16286"; # purple
        base0F = "#D65D0E"; # dark orange
      };
    };

    cursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    fonts = {
      serif = {
        package = pkgs.maple-mono.NF-CN;
        name = "Maple Mono NF CN";
      };
      sansSerif = {
        package = pkgs.maple-mono.NF-CN;
        name = "Maple Mono NF CN";
      };
      monospace = {
        package = pkgs.maple-mono.NF-CN;
        name = "Maple Mono NF CN";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Emoji";
      };
      sizes = {
        applications = fontSize;
        desktop = fontSize;
        popups = fontSize;
        terminal = fontSize;
      };
    };

    opacity = {
      terminal = 0.75;
    };
  };
}
