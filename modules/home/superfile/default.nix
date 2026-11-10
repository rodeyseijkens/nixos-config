{
  config,
  lib,
  pkgs,
  ...
}: let
  # Keep Superfile's theme aligned with the custom Stylix palette in
  # modules/core/stylix.nix (Rodey Gruvb0x / gruvbox-material-dark-hard).
  gruvboxTheme = {
    code_syntax_highlight = "gruvbox";

    full_screen_fg = "#D5C4A1";
    full_screen_bg = "#1D2021";

    gradient_color = ["#D79921" "#458588"];
    directory_icon_color = "#458588";

    file_panel_fg = "#D5C4A1";
    file_panel_bg = "#1D2021";
    file_panel_border = "#504945";
    file_panel_border_active = "#D79921";
    file_panel_top_directory_icon = "#458588";
    file_panel_top_path = "#D79921";
    file_panel_item_selected_fg = "#FBF1C7";
    file_panel_item_selected_bg = "#3C3836";

    footer_fg = "#D5C4A1";
    footer_bg = "#1D2021";
    footer_border = "#504945";
    footer_border_active = "#D79921";

    sidebar_fg = "#D5C4A1";
    sidebar_bg = "#1D2021";
    sidebar_title = "#458588";
    sidebar_border = "#1D2021";
    sidebar_border_active = "#D79921";
    sidebar_item_selected_fg = "#FBF1C7";
    sidebar_item_selected_bg = "#3C3836";
    sidebar_divider = "#504945";

    modal_fg = "#D5C4A1";
    modal_bg = "#282828";
    modal_border_active = "#D79921";
    modal_cancel_fg = "#1D2021";
    modal_cancel_bg = "#FB4934";
    modal_confirm_fg = "#1D2021";
    modal_confirm_bg = "#98971A";

    help_menu_hotkey = "#458588";
    help_menu_title = "#D79921";

    cursor = "#FBF1C7";
    correct = "#98971A";
    error = "#FB4934";
    hint = "#458588";
    cancel = "#FE8019";
  };
in {
  programs.superfile = {
    enable = true;
    settings = {
      theme = "rodey-gruvbox";
      code_previewer = "bat";
      transparent_background = true;
    };
    themes.rodey-gruvbox = gruvboxTheme;
  };

  # The HM module manages Superfile's package and settings; remove the
  # duplicate package entry from the generic package list.
}
