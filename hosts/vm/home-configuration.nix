{...}: {
  monitors.hyprland = {
    enable = true;
    config = ''
      monitor = Virtual-1, preferred, auto, 1
    '';
    workspaces = [
      "1,   monitor:Virtual-1"
      "2,   monitor:Virtual-1"
      "3,   monitor:Virtual-1"
      "4,   monitor:Virtual-1"
      "5,   monitor:Virtual-1"
      "9,   monitor:Virtual-1"
      "10,  monitor:Virtual-1"
    ];
  };

  modules = {
    # Code editors
    vscode.enable = true;

    # File managers
    nautilus.enable = true;

    # Misc
    spicetify.enable = false;
    legcord.enable = false;
  };
}
