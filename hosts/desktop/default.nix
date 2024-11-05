{ pkgs, ... }: 
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
    ./../../modules/drivers/amd-drivers.nix
    ./../../modules/drivers/nvidia-drivers.nix
  ];

  # Extra Module Options
  drivers.amdgpu.enable = false;
  drivers.nvidia.enable = true;

  powerManagement.cpuFreqGovernor = "performance";
}