{pkgs, ...}: {
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.supportedFilesystems = ["ntfs"];
}
