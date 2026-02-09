{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.cursor-editor;
in {
  options.modules.cursor-editor = {enable = mkEnableOption "cursor-editor";};
  config = mkIf cfg.enable {
    home.packages = [
      inputs.cursor-editor.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
