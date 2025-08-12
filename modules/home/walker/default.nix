{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  imports = [inputs.walker.homeManagerModules.default];

  home.packages = with pkgs; [
    libqalculate
  ];

  programs.walker = {
    enable = true;
    package = inputs.walker.packages.${pkgs.system}.default;
  };

  # Create out-of-store symlink to the walker config.toml file
  xdg.configFile."walker/config.toml".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/walker/config.toml");
}
