{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.handy;
  handyPkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.handy;
in {
  options.modules.handy = {enable = mkEnableOption "handy";};

  config = mkIf cfg.enable {
    # Handy: free, open source, offline speech-to-text.
    # Sourced from numtide/llm-agents.nix so we get a cached pre-built
    # binary instead of building cjpais/Handy from source (which needs
    # webkitgtk, gtk-layer-shell, onnxruntime, etc.).
    home.packages = [handyPkg];

    # Auto-start with the graphical session.
    systemd.user.services.handy = {
      Unit = {
        Description = "Handy speech-to-text";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${handyPkg}/bin/handy";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
