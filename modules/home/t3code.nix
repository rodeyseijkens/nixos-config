{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.t3code;
  system = pkgs.stdenv.hostPlatform.system;
in {
  options.modules.t3code = {enable = mkEnableOption "t3code";};
  config = mkIf cfg.enable {
    home.packages = [
      inputs.t3code.packages.${system}.t3code
    ];

    # Kilo only enables its `question` tool for app/cli/desktop/vscode and has
    # no ACP bridge for it. `kilo acp` sets KILO_CLIENT too late, so the ACP
    # session inherits the `cli` default and gets a tool it can never answer.
    xdg.desktopEntries.t3code = {
      name = "T3 Code (Beta)";
      comment = "Control surface for coding agents";
      exec = "env KILO_CLIENT=acp t3code %U";
      icon = "t3code";
      categories = ["Development"];
      settings.StartupWMClass = "t3code";
    };
  };
}
