{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.tailscale;
in {
  options.modules.tailscale = {enable = mkEnableOption "tailscale";};
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      tailscale
    ];
    services.trayscale.enable = true;
  };
}
