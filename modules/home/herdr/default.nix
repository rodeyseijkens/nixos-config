{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.herdr;
  system = pkgs.stdenv.hostPlatform.system;
  appPackages = inputs.herdr-app.packages.${system};
in {
  options.modules.herdr = {
    enable = mkEnableOption "herdr (terminal multiplexer and desktop app)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      # Terminal agent multiplexer.
      pkgs.herdr

      # Desktop app and its core. The app is wrapped with the packaged core
      # on its PATH; herdr-core also puts `hc` in the shell.
      appPackages.herdr-app
      appPackages.herdr-core
    ];

    xdg.configFile."herdr/config.toml".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/herdr/config.toml"
    );

    # codey (rodeyseijkens.codey) is installed with the `herdr-install-plugins`
    # helper (see modules/home/scripts/scripts/herdr-install-plugins.sh).
    # The TUI reads ~/.config/codey/config.toml on every start; the herdr plugin
    # pane runs the same binary and inherits it.
    xdg.configFile."codey/config.toml".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/herdr/codey-config.toml"
    );
  };
}
