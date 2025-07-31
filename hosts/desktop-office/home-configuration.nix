{...}: {
  monitors.hyprland = {
    enable = true;
    config = ''
      monitor = HDMI-A-1, 1920x1080@60, -1080x-420, 1, transform, 3
      monitor = DP-2, 1920x1080@60, 0x0, 1
      monitor = DP-3, 1920x1080@60, 1920x0, 1
    '';
    workspaces = [
      "1,   monitor:DP-2"
      "2,   monitor:DP-2"
      "3,   monitor:DP-2"
      "4,   monitor:DP-2"
      "5,   monitor:DP-2"
      "8,   monitor:DP-3"
      "9,   monitor:HDMI-A-1"
      "10,  monitor:HDMI-A-1"
    ];
  };

  modules = {
    # Browser
    zen-browser.enable = true;
    google-chrome.enable = true;

    # Code editors
    vscode.enable = true;

    # File managers
    nautilus.enable = true;

    # Misc
    spicetify.enable = true;
    legcord.enable = true;
    tigervnc.enable = true;
  };
}
