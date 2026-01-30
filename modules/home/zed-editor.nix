{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.zed-editor;
in {
  options.modules.zed-editor = {enable = mkEnableOption "zed-editor";};
  config = mkIf cfg.enable {
    programs.zed-editor.enable = true;
  };
}
