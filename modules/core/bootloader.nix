{
  pkgs,
  config,
  lib,
  ...
}: {
  options = {
    boot.kernelVariant = lib.mkOption {
      type = lib.types.str;
      default = "zen";
      description = "Kernel variant to use (zen, latest, lts, hardened, etc.)";
    };
  };

  config = {
    boot.loader.efi.canTouchEfiVariables = lib.mkIf config.boot.loader.systemd-boot.enable true;
    boot.loader.systemd-boot.configurationLimit = lib.mkIf config.boot.loader.systemd-boot.enable 10;

    # Kernel selection based on variant option
    boot.kernelPackages =
      if config.boot.kernelVariant == "zen"
      then pkgs.linuxPackages_zen
      else if config.boot.kernelVariant == "latest"
      then pkgs.linuxPackages_latest
      else if config.boot.kernelVariant == "lts"
      then pkgs.linuxPackages
      else if config.boot.kernelVariant == "hardened"
      then pkgs.linuxPackages_hardened
      else pkgs.linuxPackages_zen; # default fallback

    boot.supportedFilesystems = ["ntfs"];
  };
}
