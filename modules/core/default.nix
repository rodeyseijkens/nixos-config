{...}: {
  imports = [
    ./drivers/amd-drivers.nix
    ./drivers/nvidia-drivers.nix
    ./bootloader.nix
    ./hardware.nix
    ./xserver.nix
    ./network.nix
    ./nh.nix
    ./pipewire.nix
    ./program.nix
    ./security.nix
    ./services.nix
    ./system.nix
    ./flatpak.nix
    ./user.nix
    ./wayland.nix
    ./virtualization.nix

    # gaming
    ./gaming/steam.nix
    ./gaming/star-citizen.nix
  ];
}
