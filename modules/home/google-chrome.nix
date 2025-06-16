{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.google-chrome;
in {
  options.modules.google-chrome = {enable = mkEnableOption "google-chrome";};
  config = mkIf cfg.enable {
    programs.chromium = {
      enable = true;
      package = pkgs.google-chrome;
      commandLineArgs = [
        "--enable-features=UseOzonePlatform"
        "--ozone-platform=wayland"
      ];
      # extensions = [
      #   {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";} # ublock origin
      #   {id = "hfjbmagddngcpeloejdejnfgbamkjaeg";} # vimium-c
      # ];
    };
  };
}
