{...}: {
  # Desktop Environment Power Management
  powerManagement.cpuFreqGovernor = "performance";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1";

  # Driver Options
  drivers = {
    amdgpu.enable = false;
    nvidiagpu.enable = true;
  };

  services = {
    tailscale.enable = true;
  };

  flatpaks = [
    "io.beekeeperstudio.Studio"
  ];
}
