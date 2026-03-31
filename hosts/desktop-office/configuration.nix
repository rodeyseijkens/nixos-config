{...}: {
  # Desktop Environment Power Management
  powerManagement.cpuFreqGovernor = "performance";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.firewall.allowedTCPPortsCustom = [];

  # Driver Options
  drivers = {
    amdgpu.enable = true;
    nvidiagpu.enable = false;
  };

  services = {
    tailscale.enable = true;
  };

  flatpaks = [
    "io.beekeeperstudio.Studio"
  ];
}
