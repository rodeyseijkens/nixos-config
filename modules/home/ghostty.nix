{
  pkgs,
  host,
  ...
}: {
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      font-family = [
        "Maple Mono"
      ];
      font-size = 12;
      font-feature = [
        "calt"
        "ss03"
      ];

      bold-is-bright = false;
      selection-invert-fg-bg = true;

      # Theme
      theme = "gruvbox";
      background-opacity = 0.66;

      cursor-style = "bar";
      cursor-style-blink = false;
      adjust-cursor-thickness = 1;

      resize-overlay = "never";
      copy-on-select = false;
      confirm-close-surface = false;
      mouse-hide-while-typing = true;

      window-theme = "ghostty";
      window-padding-x = 10;
      window-padding-y = 6;
      window-padding-balance = true;
      window-padding-color = "background";
      window-inherit-working-directory = true;
      window-inherit-font-size = true;
      window-decoration = false;

      gtk-titlebar = false;
      gtk-single-instance = false;
      gtk-tabs-location = "bottom";
      gtk-wide-tabs = false;

      auto-update = "off";
      term = "ghostty";
      clipboard-paste-protection = false;

      keybind = [
        "shift+end=unbind"
        "shift+home=unbind"
        "ctrl+shift+left=unbind"
        "ctrl+shift+right=unbind"
        "shift+enter=text:\n"
      ];
    };

    themes.gruvbox = {
      background = "1D2021";
      foreground = "FBF1C7";

      cursor-color = "D5C4A1";

      selection-foreground = "282828";
      selection-background = "98971A";

      palette = [
        "0=#32302F"
        "1=#CC241D"
        "2=#98971A"
        "3=#D79921"
        "4=#458588"
        "5=#B16286"
        "6=#689D6A"
        "7=#EBDBB2"

        "8=#928374"
        "9=#FB4934"
        "10=#B8BB26"
        "11=#FABD2F"
        "12=#83A598"
        "13=#D3869B"
        "14=#8EC07C"
        "15=#FBF1C7"
      ];
    };
  };
}
