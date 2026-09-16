{pkgs, ...}: {
  virtualisation.docker.enable = true;

  services = {
    devmon.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;
    openssh = {
      enable = true;
      generateHostKeys = true;
    };
    gnome.gnome-keyring.enable = true;
    dbus.enable = true;
    fstrim.enable = true;

    # needed for GNOME services outside of GNOME Desktop
    # gcr needs an explicit ABI version; gnome-keyring's D-Bus prompter is gcr_3
    dbus.packages = with pkgs; [
      gcr_3
      gnome-settings-daemon
    ];

    logind.settings.Login.HandlePowerKey = "ignore";
  };
}
