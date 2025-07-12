{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.cura = {
    enable = lib.mkEnableOption "Enable Cura 3D printing slicer";
  };

  config = lib.mkIf config.modules.cura.enable {
    home.packages = with pkgs; [
      cura-appimage # 3D printing slicer
    ];
  };
}
