{
  pkgs,
  lib,
  config,
  ...
}: {
  home.packages = [pkgs.herdr];

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
}
