{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.printing3d = {
    enable = lib.mkEnableOption "Enable 3D printing slicers";
  };

  config = lib.mkIf config.modules.printing3d.enable {
    home.packages = with pkgs; [
      cura-appimage # 3D printing slicer
      LycheeSlicer # Resin 3D printing slicer
    ];
  };
}
