{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  pluginDir = ./plugins;
  pluginEntries = builtins.readDir pluginDir;

  regularFiles = builtins.filter (name: pluginEntries.${name} == "regular") (
    builtins.attrNames pluginEntries
  );

  shellPlugins =
    builtins.filter (
      name: builtins.match ".*\\.sh$" name != null
    )
    regularFiles;

  # Create a derivation for each plugin
  mkPlugin = name: {
    name = name;
    value = "${pluginDir}/${name}";
  };

  pluginsSet = builtins.listToAttrs (map mkPlugin shellPlugins);
in {
  imports = [inputs.walker.homeManagerModules.default];

  home.packages = with pkgs; [
    libqalculate
  ];

  programs.walker = {
    enable = true;
    package = inputs.walker.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  # Create out-of-store symlink to the walker config.toml file
  xdg.configFile."walker/config.toml".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/walker/config.toml");

  # Create plugins in the walker plugins directory
  home.file =
    builtins.mapAttrs
    (name: value: {
      target = ".config/walker/plugins/${name}";
      source = value;
      executable = true;
    })
    pluginsSet;
}
