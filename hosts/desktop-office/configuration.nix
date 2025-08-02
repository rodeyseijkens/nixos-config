{...}: {
  # Desktop Environment Power Management
  powerManagement.cpuFreqGovernor = "performance";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1p1";
  boot.loader.grub.useOSProber = true;

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
