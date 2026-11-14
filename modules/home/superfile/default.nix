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
    # Superfile errors out when a field from its config struct is missing from
    # config.toml, so keep the full v1.6 default set here (values taken from
    # `superfile --fix-config-file`) and override only what we care about.
    settings = {
      # general
      editor = "";
      dir_editor = "";
      auto_check_update = true;
      cd_on_quit = false;
      default_open_file_preview = true;
      show_image_preview = true;
      show_panel_footer_info = true;
      default_directory = ".";
      file_size_use_si = false;
      default_sort_type = 0;
      sort_order_reversed = false;
      case_sensitive_sort = false;
      shell_close_on_success = false;
      debug = false;
      ignore_missing_fields = false;
      page_scroll_size = 0;
      file_panel_extra_columns = 0;
      file_panel_name_percent = 50;

      # style
      nerdfont = true;
      show_select_icons = true;
      transparent_background = true;
      file_preview_width = 0;
      enable_file_preview_border = false;
      code_previewer = "bat";
      sidebar_width = 20;
      sidebar_sections = ["home" "pinned" "disks"];
      border_top = "─";
      border_bottom = "─";
      border_left = "│";
      border_right = "│";
      border_top_left = "╭";
      border_top_right = "╮";
      border_bottom_left = "╰";
      border_bottom_right = "╯";
      border_middle_left = "├";
      border_middle_right = "┤";
      theme = "rodey-gruvbox";

      # plugins
      metadata = false;
      enable_md5_checksum = false;
      zoxide_support = false;
    };

    # Same story for hotkeys: v1.6 added keys, and a missing one aborts start-up.
    hotkeys = {
      # global
      confirm = ["enter" "right" "l"];
      quit = ["q" "esc"];
      cd_quit = ["Q" ""];

      # movement
      list_up = ["up" "k"];
      list_down = ["down" "j"];
      page_up = ["pgup" ""];
      page_down = ["pgdown" ""];

      # file panel control
      create_new_file_panel = ["n" ""];
      close_file_panel = ["w" ""];
      split_file_panel = ["N" ""];
      next_file_panel = ["tab" "L"];
      previous_file_panel = ["shift+left" "H"];
      toggle_file_preview_panel = ["f" ""];
      open_sort_options_menu = ["o" ""];
      toggle_reverse_sort = ["R" ""];

      # change focus
      focus_on_process_bar = ["p" ""];
      focus_on_sidebar = ["s" ""];
      focus_on_metadata = ["m" ""];

      # create file/directory and rename
      file_panel_item_create = ["ctrl+n" ""];
      file_panel_item_rename = ["ctrl+r" ""];

      # file operations
      copy_items = ["ctrl+c" ""];
      cut_items = ["ctrl+x" ""];
      paste_items = ["ctrl+v" "ctrl+w" ""];
      delete_items = ["ctrl+d" "delete" ""];
      permanently_delete_items = ["D" ""];

      # compress and extract
      extract_file = ["ctrl+e" ""];
      compress_file = ["ctrl+a" ""];

      # editor
      open_file_with_editor = ["e" ""];
      open_current_directory_with_editor = ["E" ""];

      # other
      pinned_directory = ["P" ""];
      toggle_dot_file = ["." ""];
      change_panel_mode = ["v" ""];
      open_help_menu = ["?" ""];
      open_command_line = [":" ""];
      open_spf_prompt = [">" ""];
      open_zoxide = ["z" ""];
      copy_path = ["ctrl+p" ""];
      copy_present_working_directory = ["c" ""];
      toggle_footer = ["F" ""];

      # typing
      confirm_typing = ["enter" ""];
      cancel_typing = ["ctrl+c" "esc"];

      # normal mode
      parent_directory = ["h" "left" "backspace"];
      search_bar = ["/" ""];

      # select mode
      file_panel_select_mode_items_select_down = ["shift+down" "J"];
      file_panel_select_mode_items_select_up = ["shift+up" "K"];
      file_panel_select_all_items = ["A" ""];
    };

    themes.rodey-gruvbox = gruvboxTheme;
  };

  # The HM module manages Superfile's package and settings; remove the
  # duplicate package entry from the generic package list.
}
