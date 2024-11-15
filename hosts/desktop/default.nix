{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
    ./../../modules/drivers
  ];

  # Desktop Environment Power Management
  powerManagement.cpuFreqGovernor = "performance";

  # Driver Options
  drivers = {
    amdgpu.enable = false;
    nvidiagpu.enable = true;
  };
}
