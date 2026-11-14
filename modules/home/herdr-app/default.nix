{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.herdr-app;
  system = pkgs.stdenv.hostPlatform.system;
  packages = inputs.herdr-app.packages.${system};
in {
  options.modules.herdr-app = {enable = mkEnableOption "herdr-app";};

  config = mkIf cfg.enable {
    # The app is wrapped with the packaged core on its PATH. Add herdr-core
    # too so `hc` is available in the shell, like upstream's installer.
    home.packages = [
      packages.herdr-app
      packages.herdr-core
    ];
  };
}
