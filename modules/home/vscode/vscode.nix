{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.vscode;
  marketplace = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;
  marketplace-release = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace-release;
in {
  options.modules.vscode = {enable = mkEnableOption "vscode";};
  config = mkIf cfg.enable {
    # Writable settings and keybindings using out-of-store symlinks
    home.file.".config/Code/User/settings.json".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/vscode/settings.json"
    );
    home.file.".config/Code/User/keybindings.json".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/vscode/keybindings.json"
    );

    stylix.targets.vscode.enable = false;
    programs.vscode = {
      enable = true;

      mutableExtensionsDir = true;

      profiles.default = {
        extensions =
          (with pkgs.vscode-extensions; [
            # nix language
            bbenoist.nix

            # nix formatting
            kamadorueda.alejandra
          ])
          ++ (with marketplace; [
            # github.copilot

            vivaxy.vscode-conventional-commits # commit message helper
            eamodio.gitlens # git helper
            biomejs.biome # biome code formatter
            dbaeumer.vscode-eslint # eslint
            esbenp.prettier-vscode # prettier
            editorconfig.editorconfig # editorconfig
            tamasfe.even-better-toml # toml
            yoavbls.pretty-ts-errors # pretty ts errors
            wallabyjs.quokka-vscode # quokka dev tool
            mechatroner.rainbow-csv # rainbow csv
            bradlc.vscode-tailwindcss # tailwindcss
            gruntfuggly.todo-tree # todo helper
            pflannery.vscode-versionlens # version lens
            vscodevim.vim # vim
            antfu.file-nesting # file nesting

            # Color theme
            jdinhlife.gruvbox
            jonathanharty.gruvbox-material-icon-theme
          ])
          ++ (with marketplace-release; [
            # github.copilot-chat
          ]);
      };
    };
  };
}
