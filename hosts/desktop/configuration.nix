{...}: {
  # Desktop Environment Power Management
  powerManagement.cpuFreqGovernor = "performance";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Aarambh boot menu on the desktop ESP. The work ESP is listed by PARTUUID.
  aarambh = {
    enable = true;
    espPartuuid = "b85a008a-8f4f-45d8-a72e-26b9794d9cd4";
    volumes.work = "4a512320-ad94-44b6-883f-ba9c8a3335c2";
    entries = [
      {
        title = "NixOS (work)";
        loader = ''@work:\EFI\SYSTEMD\SYSTEMD-BOOTX64.EFI'';
        logo = "logos/nixos.png";
        background = "backgrounds/nixos.jpg";
        key = "nixos-work";
      }
      {
        title = "Windows";
        loader = ''@work:\EFI\MICROSOFT\BOOT\BOOTMGFW.EFI'';
        logo = "logos/windows.png";
        background = "backgrounds/windows.jpg";
        key = "windows";
      }
    ];
  };

  networking.firewall.allowedTCPPortsCustom = [];

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
