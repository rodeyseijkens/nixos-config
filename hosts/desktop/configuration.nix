{...}: {
  # Desktop Environment Power Management
  powerManagement.cpuFreqGovernor = "performance";

  boot.loader.systemd-boot.enable = true;

  # Driver Options
  drivers = {
    amdgpu.enable = false;
    nvidiagpu.enable = true;
  };

  core = {
    steam.enable = true;
    star-citizen.enable = true;
  };
}
