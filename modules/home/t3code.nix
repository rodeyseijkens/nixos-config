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
  llm = inputs.llm-agents.packages.${system};
  codex = llm.codex.overrideAttrs (old: {
    dontCargoUseSystemLibs = true;
    buildInputs = (old.buildInputs or []) ++ [pkgs.aws-lc];
  });
  t3code = llm.t3code.override {inherit codex;};
in {
  options.modules.t3code = {enable = mkEnableOption "t3code";};
  config = mkIf cfg.enable {
    home.packages = [
      t3code
      (llm.t3code-desktop.override {inherit t3code;})
    ];
  };
}
