{...}: {
  monitors.hyprland = {
    enable = true;
    config = ''
      monitor = DP-3, 1920x1080@60, -1080x-420, 1, transform, 3
      monitor = DP-1, 1920x1080@60, 0x0, 1
      monitor = DP-4, 1920x1080@60, 1920x0, 1
    '';
    workspaces = [
      { workspace = "1"; monitor = "DP-1"; default = true; }
      { workspace = "2"; monitor = "DP-1"; }
      { workspace = "3"; monitor = "DP-1"; }
      { workspace = "4"; monitor = "DP-1"; }
      { workspace = "5"; monitor = "DP-1"; }
      { workspace = "8"; monitor = "DP-3"; }
      { workspace = "9"; monitor = "DP-3"; default = true; }
      { workspace = "10"; monitor = "DP-3"; }
    ];
  };

  modules = {
    # Browser
    defaultBrowser = "google-chrome";
    zen-browser.enable = true;
    google-chrome = {
      enable = true;
      initialSpawnWorkspace = "10";
    };

    # Code editors
    vscode.enable = true;
    cursor-editor.enable = true;
    zed-editor.enable = true;
    helix-editor.enable = true;
    t3code.enable = false;
    handy.enable = true;

    # DevPod
    devpod.enable = true;

    # File managers
    nautilus.enable = true;

    # Misc
    spicetify.enable = true;
    tigervnc.enable = true;
  };
}
