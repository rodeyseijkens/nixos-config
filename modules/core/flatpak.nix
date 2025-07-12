{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  flatpakPackages = config.flatpaks;
in {
  imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];

  options.flatpaks = mkOption {
    type = types.listOf types.str;
    default = [];
    description = "List of Flatpak packages to install";
  };

  config = mkIf (flatpakPackages != []) {
    services.flatpak = {
      enable = true;
      packages =
        [
          "com.github.tchx84.Flatseal"
        ]
        ++ flatpakPackages;
      overrides = {
        global = {
          # Force Wayland by default
          Context.sockets = ["wayland" "!x11" "!fallback-x11"];
        };
      };
    };
  };
}
