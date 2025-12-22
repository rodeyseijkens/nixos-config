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

  programs.walker.enable = true;

  # Create out-of-store symlink to the walker config.toml file
  xdg.configFile."walker/config.toml".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/walker/config.toml");

  # Link the theme directory
  xdg.configFile."walker/themes/gruvbox".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/walker/themes/gruvbox");

  # Link elephant configs
  xdg.configFile."elephant/calc.toml".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/walker/elephant/calc.toml");
  xdg.configFile."elephant/desktopapplications.toml".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/walker/elephant/desktopapplications.toml");

  # Link elephant menus
  xdg.configFile."elephant/menus".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/walker/elephant/menus");
}
