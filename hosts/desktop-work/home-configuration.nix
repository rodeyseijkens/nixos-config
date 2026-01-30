{...}: {
  # Monitor configuration for desktop-work (same as desktop)
  monitors.hyprland = {
    enable = true;
    config = ''
      monitor = DP-2, 2560x1440@165, -2560x0, 1
      monitor = DP-3, 2560x1440@165, 0x0, 1
    '';
    workspaces = [
      "1, monitor:DP-3, default:true"
      "2, monitor:DP-3"
      "3, monitor:DP-3"
      "4, monitor:DP-3"
      "5, monitor:DP-3"
      "9, monitor:DP-2, default:true"
      "10, monitor:DP-2"
    ];
    windowrules = [
      "workspace 10, match:class ^(google-chrome)$"
    ];
  };

  # Audio configuration for desktop-work
  audio.pipewire = {
    enable = true;
    cards = {
      # GA102 High Definition Audio Controller - Off
      "alsa_card.pci-0000_09_00.1" = {
        profile = "off";
      };
      # SMSL AD-18 Amplifier - Pro Audio
      "alsa_card.usb-SMSL_AUDIO_SMSL_AD-18_Amplifier-00" = {
        profile = "pro-audio";
      };
      # HD Pro Webcam C920 - Off
      "alsa_card.usb-046d_HD_Pro_Webcam_C920_09E4D43F-02" = {
        profile = "off";
      };
      # RODE NT-USB - Analog Stereo Input
      "alsa_card.usb-RODE_Microphones_RODE_NT-USB-00" = {
        profile = "input:analog-stereo";
      };
      # Starship/Matisse HD Audio Controller - Off
      "alsa_card.pci-0000_0b_00.4" = {
        profile = "off";
      };
    };
    # Set default devices based on your setup
    defaultSink = "alsa_output.usb-SMSL_AUDIO_SMSL_AD-18_Amplifier-00.pro-output-0";
    defaultSource = "alsa_input.usb-RODE_Microphones_RODE_NT-USB-00.analog-stereo";
  };

  modules = {
    # Browser
    zen-browser.enable = true;
    google-chrome.enable = true;

    # Code editors
    vscode.enable = true;
    cursor-editor.enable = true;
    zed-editor.enable = true;

    # File managers
    nautilus.enable = true;

    # Misc
    spicetify.enable = true;
    legcord.enable = true;
    tigervnc.enable = true;
  };
}
