{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    awww
    inputs.hypr-contrib.packages.${pkgs.stdenv.hostPlatform.system}.grimblast
    inputs.hyprpicker.packages.${pkgs.stdenv.hostPlatform.system}.hyprpicker
    inputs.hyprmag.packages.${pkgs.stdenv.hostPlatform.system}.hyprmag
    slurp
    grim # screenshot by output or geometry (grimblast only wraps it privately)
    wlrctl # virtual pointer/keyboard: click, scroll, type
    wl-clip-persist
    cliphist
    wf-recorder
    glib
    wayland
    direnv
  ];

  systemd.user.targets.hyprland-session.Unit.Wants = ["xdg-desktop-autostart.target"];
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;

    xwayland = {
      enable = true;
      # hidpi = true;
    };

    systemd = {
      enable = true;
      enableXdgAutostart = true;
      variables = ["--all"];
    };
  };
}
