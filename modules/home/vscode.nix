{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.vscode;
  marketplace = inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace;
  marketplace-release = inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace-release;
in {
  options.modules.vscode = {enable = mkEnableOption "vscode";};
  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      extensions =
        (with pkgs.vscode-extensions; [
          # nix language
          bbenoist.nix

          # nix formatting
          kamadorueda.alejandra
        ])
        ++ (with marketplace; [
          github.copilot

          vivaxy.vscode-conventional-commits # commit message helper
          eamodio.gitlens

          # Color theme
          jdinhlife.gruvbox
          jonathanharty.gruvbox-material-icon-theme
        ])
        ++ (with marketplace-release; [
          github.copilot-chat
        ]);
      userSettings = {
        "update.mode" = "none";

        "editor.fontFamily" = "'Maple Mono', 'SymbolsNerdFont', 'monospace', monospace";
        "editor.fontLigatures" = true;
        "editor.fontSize" = 18;

        "editor.formatOnPaste" = true;
        "editor.formatOnSave" = true;
        "editor.formatOnType" = true;

        "editor.minimap.enabled" = true;
        "editor.mouseWheelZoom" = true;
        "editor.renderControlCharacters" = false;
        "editor.scrollbar.horizontalScrollbarSize" = 5;
        "editor.scrollbar.verticalScrollbarSize" = 5;

        "explorer.confirmDragAndDrop" = false;
        "explorer.openEditors.visible" = 0;

        "extensions.autoUpdate" = false; # This stuff fixes vscode freaking out when theres an update

        "files.autoSave" = "onWindowChange";
        "terminal.integrated.fontFamily" = "'Maple Mono', 'SymbolsNerdFont'";
        "vsicons.dontShowNewVersionMessage" = true;

        "window.customTitleBarVisibility" = "auto";
        "window.menuBarVisibility" = "toggle";

        "workbench.activityBar.location" = "top";
        "workbench.colorTheme" = "Gruvbox Dark Hard";
        "workbench.editor.limit.enabled" = true;
        "workbench.editor.limit.perEditorGroup" = true;
        "workbench.editor.limit.value" = 10;
        "workbench.iconTheme" = "gruvbox-material-icon-theme";
        "workbench.layoutControl.enabled" = false;
        "workbench.layoutControl.type" = "menu";
        "workbench.startupEditor" = "none";
        "workbench.statusBar.visible" = false;

        # Extension settings
        "material-icon-theme.folders.theme" = "classic";
      };
      # Keybindings
      keybindings = [
        {
          key = "ctrl+s";
          command = "workbench.action.files.saveFiles";
        }
      ];
    };
  };
}
