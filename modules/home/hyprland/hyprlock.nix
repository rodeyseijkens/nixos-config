{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  # Color helper functions
  rgb = color: "rgb(${color})";
  rgba = color: alpha: "rgba(${color}${alpha})";
in {
  programs.hyprlock = {
    enable = true;

    package = inputs.hyprlock.packages.${pkgs.system}.hyprlock;

    settings = {
      general = {
        hide_cursor = true;
        no_fade_in = false;
        disable_loading_bar = false;
        ignore_empty_input = true;
        fractional_scaling = 0;
      };

      background = {
        monitor = "";
        path = "${../../../wallpapers/otherWallpaper/gruvbox/fern.jpg}";
        blur_passes = 2;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };

      shape = [
        # User box
        {
          monitor = "";
          size = "300, 50";
          rounding = 10;
          position = "0, 270";
          halign = "center";
          valign = "bottom";
          color = rgba config.lib.stylix.colors.base05 "33";
          border_color = rgba config.lib.stylix.colors.base07 "00";
        }
      ];

      label = [
        # Time
        {
          monitor = "";
          text = ''cmd[update:1000] echo "$(date +'%k:%M')"'';
          font_size = 115;
          font_family = "Maple Mono Bold";
          shadow_passes = 3;
          position = "0, -150";
          halign = "center";
          valign = "top";
          color = rgba config.lib.stylix.colors.base06 "E6";
        }
        # Date
        {
          monitor = "";
          text = ''cmd[update:1000] echo "- $(date +'%A, %B %d') -" '';
          font_size = 18;
          font_family = "Maple Mono";
          shadow_passes = 3;
          position = "0, -350";
          halign = "center";
          valign = "top";
          color = rgba config.lib.stylix.colors.base06 "E6";
        }
        # Username
        {
          monitor = "";
          text = "  $USER";
          font_size = 15;
          font_family = "Maple Mono Bold";
          position = "0, 281";
          halign = "center";
          valign = "bottom";
          color = rgba config.lib.stylix.colors.base06 "FF";
        }
      ];

      input-field = lib.mkForce {
        monitor = "";
        size = "300, 50";
        outline_thickness = 1;
        rounding = 10;
        dots_size = 0.25;
        dots_spacing = 0.4;
        dots_center = true;
        font_size = 14;
        font_family = "Maple Mono Bold";
        fade_on_empty = false;
        placeholder_text = ''<i><span foreground="##fbf1c7">Enter Password</span></i>'';
        hide_input = false;
        position = "0, 200";
        halign = "center";
        valign = "bottom";
        outer_color = rgba config.lib.stylix.colors.base05 "33";
        inner_color = rgba config.lib.stylix.colors.base05 "33";
        color = rgba config.lib.stylix.colors.base06 "E6";
        font_color = rgba config.lib.stylix.colors.base06 "E6";
      };
    };
  };
}
