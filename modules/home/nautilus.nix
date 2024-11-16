{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.nautilus;
in {
  options.modules.nautilus = {enable = mkEnableOption "nautilus";};
  config = mkIf cfg.enable {
    home.packages = with pkgs; [nautilus];

    dconf.settings = {
      "org/gnome/nautilus/preferences" = {
        date-time-format = "detailed";
        default-folder-viewer = "list-view";
        migrated-gtk-settings = true;
        search-filter-time-type = "last_modified";
        show-delete-permanently = false;
      };
      "org/gnome/nautilus/list-view" = {
        default-zoom-level = "small";
        use-tree-view = false;
      };
      "org/gnome/nautilus/icon-view" = {
        default-zoom-level = "small";
      };
      "org/gnome/nautilus/window-state" = {
        maximized = true;
      };
    };
  };
}
