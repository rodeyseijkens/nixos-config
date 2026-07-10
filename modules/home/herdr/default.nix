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

  # herdr-reviewr (persiyanov.herdr-reviewr) reads its config from
  # $HERDR_PLUGIN_CONFIG_DIR/config.toml on every refresh; herdr sets that
  # env var to ~/.config/herdr/plugins/config/persiyanov.reviewr.
  xdg.configFile."herdr/plugins/config/persiyanov.reviewr/config.toml".source = lib.mkForce (
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/herdr/reviewr-config.toml"
  );
}
