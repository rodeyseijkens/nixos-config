{pkgs, ...}: let
  wall-change = pkgs.writeShellScriptBin "wall-change" (builtins.readFile ./scripts/wall-change.sh);
  wallpaper-picker = pkgs.writeShellScriptBin "wallpaper-picker" (builtins.readFile ./scripts/wallpaper-picker.sh);

  runbg = pkgs.writeShellScriptBin "runbg" (builtins.readFile ./scripts/runbg.sh);
  lofi = pkgs.writeScriptBin "lofi" (builtins.readFile ./scripts/lofi.sh);

  toggle_blur = pkgs.writeScriptBin "toggle_blur" (builtins.readFile ./scripts/toggle_blur.sh);
  toggle_opacity = pkgs.writeScriptBin "toggle_opacity" (builtins.readFile ./scripts/toggle_opacity.sh);
  toggle_waybar = pkgs.writeScriptBin "toggle_waybar" (builtins.readFile ./scripts/toggle_waybar.sh);
  toggle_float = pkgs.writeScriptBin "toggle_float" (builtins.readFile ./scripts/toggle_float.sh);

  compress = pkgs.writeScriptBin "compress" (builtins.readFile ./scripts/compress.sh);
  extract = pkgs.writeScriptBin "extract" (builtins.readFile ./scripts/extract.sh);

  shutdown-script = pkgs.writeScriptBin "shutdown-script" (builtins.readFile ./scripts/shutdown-script.sh);

  show-keybinds = pkgs.writeScriptBin "show-keybinds" (builtins.readFile ./scripts/keybinds.sh);

  vm-start = pkgs.writeScriptBin "vm-start" (builtins.readFile ./scripts/vm-start.sh);

  ascii = pkgs.writeScriptBin "ascii" (builtins.readFile ./scripts/ascii.sh);

  record = pkgs.writeScriptBin "record" (builtins.readFile ./scripts/record.sh);

  screenshot = pkgs.writeScriptBin "screenshot" (builtins.readFile ./scripts/screenshot.sh);

  rofi-power-menu = pkgs.writeScriptBin "rofi-power-menu" (builtins.readFile ./scripts/rofi-power-menu.sh);
  power-menu = pkgs.writeScriptBin "power-menu" (builtins.readFile ./scripts/power-menu.sh);
in {
  home.packages = with pkgs; [
    wall-change
    wallpaper-picker

    runbg
    lofi

    toggle_blur
    toggle_opacity
    toggle_waybar
    toggle_float

    compress
    extract

    shutdown-script

    show-keybinds

    vm-start

    ascii

    record

    screenshot

    rofi-power-menu
    power-menu

    gifsicle # gif utility - for record.sh
    zenity # simple dialog creator - for record.sh
    swappy # snapshot editing tool - for screenshot.sh
  ];
}
