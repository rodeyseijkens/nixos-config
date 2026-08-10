{
  lib,
  config,
  ...
}: let
  # Nerd Font glyphs that may not survive copy-paste
  pl_left_square = "░▒▓";
  pl_right_square = "▓▒░";
  pl_right_sharp = "";
  pl_left_sharp = "";
  arrow_right = "→";
  arrow_left = "←";

  stylixColors = config.lib.stylix.colors.withHashtag;
in {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      palette = lib.mkForce "gruvb0x_dark";

      palettes.gruvb0x_dark = lib.mkForce {
        color_fg0 = stylixColors.base07;
        color_fg1 = stylixColors.base00;
        color_bg1 = stylixColors.base01;
        color_bg3 = stylixColors.base03;
        color_bg4 = stylixColors.base04;
        color_blue = stylixColors.base0B;
        color_aqua = stylixColors.base0C;
        color_green = stylixColors.base0D;
        color_orange = stylixColors.base0F;
        color_purple = stylixColors.base0E;
        color_red = stylixColors.base08;
        color_yellow = stylixColors.base0A;
      };

      format = lib.mkForce (lib.concatStrings [
        "[${pl_left_square}](color_blue)"
        "$directory"
        "[${pl_right_sharp}](fg:color_blue bg:color_green)"
        "$git_branch"
        "[${pl_right_sharp}](fg:color_green)"
        "$fill"
        "[${pl_left_sharp}](fg:color_bg1)"
        "$git_status"
        "[${pl_left_sharp}](fg:color_bg4 bg:color_bg1)"
        "$time"
        "[${pl_right_square}](fg:color_bg4)"
        "$line_break"
        "$character"
      ]);

      # os = {
      #   disabled = false;
      #   style = "bg:color_green fg:color_fg0";
      #   symbols = {
      #     Windows = " 󰍲";
      #     Ubuntu = " 󰕈";
      #     SUSE = " ";
      #     Raspbian = " ";
      #     Mint = " 󰣭";
      #     Macos = " 󰀵";
      #     Manjaro = " 󱘊";
      #     Linux = " 󰌽";
      #     Gentoo = " 󰣨";
      #     Fedora = " 󰣛";
      #     Alpine = " ";
      #     Amazon = " ";
      #     Android = " ";
      #     Arch = " 󰣇";
      #     Debian = " 󰣚";
      #     Redhat = " 󱄛";
      #     RedHatEnterprise = " 󱄛";
      #     Pop = " 󰌪";
      #     NixOS = " ";
      #   };
      # };

      username = {
        show_always = false;
        style_user = "bg:color_green fg:color_fg0";
        style_root = "bg:color_green fg:color_fg0";
        format = "[ $user ]($style)";
      };

      directory = {
        style = "fg:color_fg0 bg:color_blue";
        format = "[ $path ]($style)";
        truncation_symbol = "…/";
        truncation_length = 3;
        truncate_to_repo = false;
        substitutions = {
          "Documents" = "";
          "Downloads" = "";
          "Music" = "󰝚";
          "Videos" = "";
          "Pictures" = "";
          "Projects" = "󰲋";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:color_green";
        format = "[[ $symbol $branch ](fg:color_bg1 bg:color_green)]($style)";
      };

      git_status = {
        style = "bg:color_bg1";
        format = "[[($all_status$ahead_behind )](fg:color_fg0 bg:color_bg1)]($style)";
        conflicted = "[   $count](fg:color_red bg:color_bg1)";
        stashed = "";
        modified = "[   $count](fg:color_blue bg:color_bg1)";
        staged = "[   $count](fg:color_green bg:color_bg1)";
        renamed = "[   $count](fg:color_yellow bg:color_bg1)";
        deleted = "[   $count](fg:color_red bg:color_bg1)";
        untracked = "[   $count](fg:color_bg3 bg:color_bg1)";
        ahead = "[   $count](fg:color_green bg:color_bg1)";
        behind = "[   $count](fg:color_red bg:color_bg1)";
        diverged = "[  $ahead_count  $behind_count](fg:color_purple bg:color_bg1)";
      };

      nix_shell = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol ](fg:color_fg0 bg:color_orange)]($style)";
        heuristic = false;
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_bg1";
        format = "[[  $time ](fg:color_fg1 bg:color_bg4)]($style)";
      };

      line_break.disabled = false;

      fill = {
        symbol = " ";
      };

      character = {
        disabled = false;
        success_symbol = "[${arrow_right}](bold fg:color_green)";
        error_symbol = "[${arrow_right}](bold fg:color_red)";
        vimcmd_symbol = "[${arrow_left}](bold fg:color_green)";
        vimcmd_replace_one_symbol = "[${arrow_left}](bold fg:color_purple)";
        vimcmd_replace_symbol = "[${arrow_left}](bold fg:color_purple)";
        vimcmd_visual_symbol = "[${arrow_left}](bold fg:color_yellow)";
      };
    };
  };
}
