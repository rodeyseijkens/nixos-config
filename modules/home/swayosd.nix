{
  lib,
  pkgs,
  ...
}: let
  inherit (import ./hyprland/hyprland-util.nix { inherit lib; })
    bind bindLocked bindLockedRepeat bindRelease exec;
in {
  home.packages = with pkgs; [swayosd];

  modules.hyprland.startup = [
    "swayosd-server"
  ];

  wayland.windowManager.hyprland.settings = {
    bind = [
      (bind ", XF86AudioMute" (exec "swayosd-client --output-volume mute-toggle"))
      (bindLocked ", XF86MonBrightnessUp" (exec "swayosd-client --brightness raise 5%+"))
      (bindLocked ", XF86MonBrightnessDown" (exec "swayosd-client --brightness lower 5%-"))
      (bindLocked "SUPER, XF86MonBrightnessUp" (exec "brightnessctl set 100%"))
      (bindLocked "SUPER, XF86MonBrightnessDown" (exec "brightnessctl set 0%"))
      (bindLockedRepeat ", XF86AudioRaiseVolume" (exec "swayosd-client --output-volume raise --max-volume=100"))
      (bindLockedRepeat ", XF86AudioLowerVolume" (exec "swayosd-client --output-volume lower"))
      (bindLockedRepeat "SUPER, f11" (exec "swayosd-client --output-volume +2 --max-volume=100"))
      (bindLockedRepeat "SUPER, f12" (exec "swayosd-client --output-volume -2"))
      (bindRelease ", Caps_Lock" (exec "swayosd-client --caps-lock"))
      (bindRelease ", Scroll_Lock" (exec "swayosd-client --scroll-lock"))
      (bindRelease ", Num_Lock" (exec "swayosd-client --num-lock"))
    ];
  };

  xdg.configFile."swayosd/style.css".text = ''
    window {
        padding: 0px 10px;
        border-radius: 30px;
        border: 10px;
        background: alpha(#111111, 0.99);
    }

    #container {
        margin: 15px;
    }

    image, label {
        color: #FBF1C7;
    }

    progressbar:disabled,
    image:disabled {
        opacity: 0.95;
    }

    progressbar {
        min-height: 6px;
        border-radius: 999px;
        background: transparent;
        border: none;
    }
    trough {
        min-height: inherit;
        border-radius: inherit;
        border: none;
        background: alpha(#CCCCCC, 0.1);
    }
    progress {
        min-height: inherit;
        border-radius: inherit;
        border: none;
        background: #FBF1C7;
    }
  '';
}