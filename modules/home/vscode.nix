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
        userSettings = {
          "update.mode" = "none";

          "editor.fontLigatures" = true;

          "editor.formatOnPaste" = true;
          "editor.formatOnSave" = true;
          "editor.formatOnType" = false;

          "editor.codeActionsOnSave" = {
            "source.fixAll.eslint" = "explicit";
          };

          "editor.minimap.enabled" = true;
          "editor.mouseWheelZoom" = true;
          "editor.renderControlCharacters" = false;
          "editor.scrollbar.horizontalScrollbarSize" = 5;
          "editor.scrollbar.verticalScrollbarSize" = 5;

          "explorer.confirmDragAndDrop" = false;
          "explorer.openEditors.visible" = 0;
          "explorer.fileNesting.enabled" = true;

          "extensions.autoUpdate" = false; # This stuff fixes vscode freaking out when theres an update

          "files.autoSave" = "onWindowChange";
          "terminal.integrated.fontFamily" = "'Maple Mono', 'SymbolsNerdFont'";
          "terminal.integrated.tabs.enabled" = false;
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
          "workbench.statusBar.visible" = true;
          "workbench.panel.showLabels" = false;
          "workbench.panel.defaultLocation" = "right";

          "chat.agentSessionsViewLocation" = "single-view";
          "chat.viewSessions.orientation" = "stacked";

          # Extension settings
          "alejandra.program" = "alejandra";
          "material-icon-theme.folders.theme" = "classic";
          "gitlens.rebaseEditor.ordering" = "asc";
          "github.copilot.nextEditSuggestions.enabled" = true;
          "vim.disableExtension" = true;
          "[nix]" = {
            "editor.defaultFormatter" = "kamadorueda.alejandra";
          };
          "[json]" = {
            "editor.defaultFormatter" = "vscode.json-language-features";
          };
          "[typescript]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[javascript]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[typescriptreact]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[css]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
        };
        # Keybindings
        keybindings = [
          {
            "command" = "workbench.action.files.saveFiles";
            "key" = "ctrl+s";
          }
          {
            "command" = "workbench.action.terminal.killAll";
            "key" = "ctrl+alt+meta+delete";
          }
        ];
      };
    };
  };
}
