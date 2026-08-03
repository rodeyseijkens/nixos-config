{...}: {
  # Desktop Environment Power Management
  powerManagement.cpuFreqGovernor = "performance";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/73de11ef-2cd1-49d2-bc5b-fad43c7d26b7";
    }
  ];

  networking.firewall.allowedTCPPortsCustom = [];

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
