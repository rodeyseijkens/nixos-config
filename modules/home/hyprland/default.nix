{inputs, ...}: {
  imports = [
    ./hyprland.nix
    ./config.nix
    ./hyprlock.nix
    ./env.nix
    ./exec-once.nix
    ./binds.nix
    inputs.hyprland.homeManagerModules.default
  ];
}
