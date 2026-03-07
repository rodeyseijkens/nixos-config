{
  pkgs,
  stylix,
  lib,
  config,
  ...
}: {
  options.theme = {
    fontSize = lib.mkOption {
      type = lib.types.int;
      default = 12;
      description = "Base font size for all applications";
    };

    themeName = lib.mkOption {
      type = lib.types.str;
      default = "gruvbox-material-dark-hard";
      description = "Base16 theme name (if using external theme)";
    };

    useCustomGruvbox = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use custom Gruvbox color scheme instead of base16-schemes";
    };
  };

  config = let
    cfg = config.theme;
  in {
    stylix = {
      enable = true;
      autoEnable = lib.mkDefault true;
      polarity = "dark";

      # Use custom Gruvbox or external base16 theme
      base16Scheme =
        if cfg.useCustomGruvbox
        then {
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
            base0B = "#458588"; # blue
            base0C = "#689D6A"; # aqua/cyan
            base0D = "#98971A"; # green
            base0E = "#D16286"; # purple
            base0F = "#D65D0E"; # dark orange
          };
        }
        else "${pkgs.base16-schemes}/share/themes/${cfg.themeName}.yaml";

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
          applications = cfg.fontSize;
          desktop = cfg.fontSize;
          popups = cfg.fontSize;
          terminal = cfg.fontSize;
        };
      };

      opacity = {
        terminal = 0.75;
      };
    };
  };
}
