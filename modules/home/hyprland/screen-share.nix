{
  pkgs,
  config,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
  font = config.stylix.fonts.monospace.name;
  fontSize = config.stylix.fonts.sizes.applications;

  # Style the picker with the active Stylix palette and font. Keep corners
  # square to match Hyprland's decoration.rounding setting.
  stylesheet = pkgs.writeText "hyprland-preview-share-picker.css" ''
    @define-color bg ${colors.base00};
    @define-color card_bg ${colors.base01};
    @define-color border_soft ${colors.base02};
    @define-color muted ${colors.base04};
    @define-color text ${colors.base05};
    @define-color accent ${colors.base0D};
    @define-color accent_hover ${colors.base0A};

    * {
      all: unset;
      font-family: "${font}";
      color: @text;
      font-weight: bold;
      font-size: ${toString fontSize}px;
    }

    .window {
      background: alpha(@bg, 0.95);
      border: solid 2px @accent;
      margin: 4px;
      padding: 18px;
    }

    tabs {
      padding: 0.5rem 1rem;
    }

    tabs > tab {
      margin-right: 1rem;
    }

    .tab-label {
      color: @muted;
      transition: all 0.2s ease;
    }

    tabs > tab:checked > .tab-label,
    tabs > tab:active > .tab-label {
      color: @accent;
      text-decoration: underline currentColor;
    }

    tabs > tab:focus > .tab-label {
      color: @text;
    }

    .page {
      padding: 1rem;
    }

    .image-label {
      padding: 0.25rem;
      color: @muted;
    }

    flowboxchild > .card,
    button > .card {
      transition: all 0.2s ease;
      border: solid 2px @bg;
      background-color: @card_bg;
      padding: 5px;
    }

    flowboxchild:hover > .card,
    flowboxchild:active > .card,
    flowboxchild:selected > .card,
    button:hover > .card,
    button:active > .card,
    button:selected > .card,
    button:focus > .card {
      border: solid 2px @accent;
    }

    .card-loading {
      color: @muted;
    }

    .region-button {
      padding: 0.5rem 1rem;
      background-color: @accent;
      color: @bg;
      transition: all 0.2s ease;
    }

    .region-button > label {
      color: @bg;
    }

    .region-button:not(:disabled):hover,
    .region-button:not(:disabled):focus {
      background-color: @accent_hover;
      color: @bg;
    }

    .region-button:disabled {
      background-color: @muted;
      color: @bg;
    }

    .restore-button {
      padding: 0.5rem 1rem;
      color: @muted;
    }
  '';
in {
  home.packages = [pkgs.hyprland-preview-share-picker];

  # Allow restore tokens so follow-up portal requests can reuse the selected
  # source instead of reopening the picker. Chromium-based clients may request
  # a source once for preview and again for capture. See xdg-desktop-portal#692
  # and Chromium issue 354537406. The preview picker is configured below.
  # xdph reads this file at startup. Restart it after changing the config:
  #   systemctl --user restart xdg-desktop-portal-hyprland
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
        allow_token_by_default = true
        custom_picker_binary = ${pkgs.hyprland-preview-share-picker}/bin/hyprland-preview-share-picker
    }
  '';

  # Put outputs first and select with one click. The restore-token option is
  # hidden because xdph always passes --allow-token with the setting above.
  # Use the generated Stylix stylesheet for the picker colors and font.
  xdg.configFile."hyprland-preview-share-picker/config.yaml".text = ''
    stylesheets: ["${stylesheet}"]
    default_page: outputs
    image:
      resize_size: 500
    windows:
      clicks: 1
    outputs:
      clicks: 1
    hide_token_restore: true
  '';
}
