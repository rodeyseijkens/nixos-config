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
      inputs.llm-agents.packages.${system}.t3code
      inputs.llm-agents.packages.${system}.t3code-desktop
    ];
  };
}
