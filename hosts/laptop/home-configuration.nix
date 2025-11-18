{...}: {
  monitors.hyprland = {
    enable = true;
    config = ''
      monitor = eDP-1, preferred, auto, 1
    '';
    workspaces = [
      "1, monitor:eDP-1, default:true"
      "2, monitor:eDP-1"
      "3, monitor:eDP-1"
      "4, monitor:eDP-1"
      "5, monitor:eDP-1"
      "9, monitor:eDP-1"
      "10, monitor:eDP-1"
    ];
  };

  modules = {
    # Code editors
    vscode.enable = true;

    # File managers
    nautilus.enable = true;

    # Misc
    spicetify.enable = true;
    legcord.enable = true;
  };
}
