{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.quickshell;
  mkEntry = entry:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/quickshell/config/${entry}";
in {
  options.modules.quickshell = {
    enable =
      lib.mkEnableOption "Quickshell shell (bar, notifications, OSD)"
      // {default = true;};
  };

  config = lib.mkIf cfg.enable {
    programs.quickshell = {
      enable = true;
      # Config lives at ~/.config/quickshell/shell/ → named config "shell".
      # Must match the `qs -c shell ipc call …` binds in hyprland/binds.nix.
      activeConfig = "shell";
      systemd = {
        enable = true;
        target = "hyprland-session.target";
      };
    };

    home.packages = with pkgs; [
      brightnessctl
      pamixer
      pwvucontrol
    ];

    xdg.configFile."quickshell/shell/shell.qml".source = mkEntry "shell.qml";
    xdg.configFile."quickshell/shell/qmldir".source = mkEntry "qmldir";
    xdg.configFile."quickshell/shell/Bar".source = mkEntry "Bar";
    xdg.configFile."quickshell/shell/Panel".source = mkEntry "Panel";
    xdg.configFile."quickshell/shell/Osd".source = mkEntry "Osd";
    xdg.configFile."quickshell/shell/Services".source = mkEntry "Services";

    xdg.configFile."quickshell/shell/Colors.qml".text = import ./tokens.nix {
      colors = config.lib.stylix.colors;
    };

    xdg.configFile."quickshell/shell/.qmlls.ini".text = ''
      [General]
      importPaths=${pkgs.quickshell}/lib/qt-6/qml
    '';
  };
}
