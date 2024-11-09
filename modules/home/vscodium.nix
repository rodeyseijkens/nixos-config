{ inputs, pkgs, ... }: 
let 
  marketplace = inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace;
  marketplace-release = inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace-release;
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    extensions =
      (with pkgs.vscode-extensions; [
        # nix language
        bbenoist.nix
        # nix-shell suport 
        arrterian.nix-env-selector
      ])
      ++ (with marketplace; [
        github.copilot
        github.copilot-chat
        
        vivaxy.vscode-conventional-commits # commit message helper  

        # Color theme
        jdinhlife.gruvbox
        jonathanharty.gruvbox-material-icon-theme
      ])
      ++ (with marketplace-release; [
        ###
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
      "workbench.editor.showTabs" = "single";
      "workbench.iconTheme" = "gruvbox-material-icon-theme";
      "workbench.layoutControl.enabled" = false;
      "workbench.layoutControl.type" = "menu";
      "workbench.startupEditor" = "none";
      "workbench.statusBar.visible" = false;

      # Extension settings
      "material-icon-theme.folders.theme" = "classic";

      "C_Cpp.autocompleteAddParentheses" = true;
      "C_Cpp.formatting" = "clangFormat";
      "C_Cpp.vcFormat.newLine.closeBraceSameLine.emptyFunction" = true;
      "C_Cpp.vcFormat.newLine.closeBraceSameLine.emptyType" = true;
      "C_Cpp.vcFormat.space.beforeEmptySquareBrackets" = true;
      "C_Cpp.vcFormat.newLine.beforeOpenBrace.block" = "sameLine";
      "C_Cpp.vcFormat.newLine.beforeOpenBrace.function" = "sameLine";
      "C_Cpp.vcFormat.newLine.beforeElse" = false;
      "C_Cpp.vcFormat.newLine.beforeCatch" = false;
      "C_Cpp.vcFormat.newLine.beforeOpenBrace.type" = "sameLine";
      "C_Cpp.vcFormat.space.betweenEmptyBraces" = true;
      "C_Cpp.vcFormat.space.betweenEmptyLambdaBrackets" = true;
      "C_Cpp.vcFormat.indent.caseLabels" = true;
      "C_Cpp.intelliSenseCacheSize" = 2048;
      "C_Cpp.intelliSenseMemoryLimit" = 2048;
      "C_Cpp.default.browse.path" = [
        ''''${workspaceFolder}/**''
      ];
      "C_Cpp.default.cStandard" = "gnu11";
      "C_Cpp.inlayHints.parameterNames.hideLeadingUnderscores" = false;
      "C_Cpp.intelliSenseUpdateDelay" = 500;
      "C_Cpp.workspaceParsingPriority" = "medium";
      "C_Cpp.clang_format_sortIncludes" = true;
      "C_Cpp.doxygen.generatedStyle" = "/**";
    };
    # Keybindings
    keybindings = [
      {
        key = "ctrl+q";
        command = "editor.action.commentLine";
        when = "editorTextFocus && !editorReadonly";
      }
      {
        key = "ctrl+s";
        command = "workbench.action.files.saveFiles";
      }
    ];
  };
}
