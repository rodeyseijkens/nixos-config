{
  pkgs,
  config,
  lib,
  ...
}: {
  boot.loader.efi.canTouchEfiVariables = lib.mkIf config.boot.loader.systemd-boot.enable true;
  boot.loader.systemd-boot.configurationLimit = lib.mkIf config.boot.loader.systemd-boot.enable 10;
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.supportedFilesystems = ["ntfs"];
}
