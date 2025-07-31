{...}: {
  monitors.hyprland = {
    enable = true;
    config = ''
      monitor = DP-2, 2560x1440@165, -2560x0, 1
      monitor = DP-3, 2560x1440@165, 0x0, 1
    '';
    workspaces = [
      "1,   monitor:DP-3"
      "2,   monitor:DP-3"
      "3,   monitor:DP-3"
      "4,   monitor:DP-3"
      "5,   monitor:DP-3"
      "9,   monitor:DP-2"
      "10,  monitor:DP-2"
    ];
  };

  modules = {
    # Browser
    zen-browser.enable = true;

    # Code editors
    vscode.enable = true;

    # File managers
    nautilus.enable = true;

    # Misc
    spicetify.enable = true;
    legcord.enable = true;
    obs-studio.enable = true;
    cura.enable = true;
  };
}
