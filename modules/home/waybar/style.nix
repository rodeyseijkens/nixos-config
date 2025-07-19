{
  lib,
  stylix,
  ...
}: {
  programs.waybar.style = lib.mkAfter ''
    * {
      border: none;
      border-radius: 0px;
      padding: 0;
      margin: 0;
      opacity: 1;
      font-weight: bold;
    }

    window#waybar {
      background: @base01;
      border-top: 1px solid @base04;
    }

    tooltip {
      background: @base01;
      border: 1px solid @base04;
    }
    tooltip label {
      margin: 5px;
      color: @base07;
    }

    #workspaces {
      padding-left: 15px;
    }
    #workspaces button {
      color: @base0A;
      background: @base01;
      padding-left:  5px;
      padding-right: 5px;
      margin-right: 10px;
      border-top: 1px solid @base04;
    }
    #workspaces button.empty {
      color: @base07;
    }
    #workspaces button.focused,
    #workspaces button.active {
      color: @base09;
    }

    #tray {
      margin-left: 10px;
      color: @base07;
    }
    #tray menu {
      background: @base01;
      border: 1px solid @base04;
      padding: 8px;
    }
    #tray menuitem {
      padding: 1px;
    }

    #pulseaudio, #network, #cpu, #memory, #disk, #battery, #custom-notification {
      margin-right: 10px;
    }

    #custom-notification {
      margin-left: 15px;
      padding-right: 2px;
      margin-right: 5px;
    }

    #custom-launcher {
      font-size: 20px;
      color: @base07;
      font-weight: bold;
      margin-left: 15px;
      padding-right: 10px;
    }

    .modules-left #workspaces button,
    .modules-center #workspaces button,
    .modules-right #workspaces button {
      border-bottom: 0px solid transparent;
    }
    .modules-left #workspaces button.focused,
    .modules-left #workspaces button.active,
    .modules-center #workspaces button.focused,
    .modules-center #workspaces button.active,
    .modules-right #workspaces button.focused,
    .modules-right #workspaces button.active {
      border-bottom: 0px solid @base05;
    }
  '';
}
