{...}: {
  # Desktop Environment Power Management
  powerManagement.cpuFreqGovernor = "performance";

  # Driver Options
  drivers = {
    amdgpu.enable = false;
    nvidiagpu.enable = true;
  };

  services = {
    tailscale.enable = true;
  };
}
