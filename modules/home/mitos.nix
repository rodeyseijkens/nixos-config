{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.mitos-editor;
  colors = config.lib.stylix.colors;
  system = pkgs.stdenv.hostPlatform.system;
in {
  options.modules.mitos-editor = {enable = mkEnableOption "mitos-editor";};

  config = mkIf cfg.enable {
    home.packages =
      [
        inputs.mitos.packages.${system}.default
      ]
      ++ (with pkgs; [
        typescript-language-server
        typescript
        biome
        vscode-langservers-extracted
        nil
        ruff
        basedpyright
        taplo
        yaml-language-server
        marksman
        bash-language-server
        shfmt
        tailwindcss-language-server
      ]);

    xdg.configFile."mitos/config.toml".text = ''
      theme = "stylix"

      [editor.cursor]
      highlight-line = true

      [editor.format]
      on-save = true

      [editor.indent-guides]
      render = true

      [editor.file-picker]
      hidden = false
      git-ignore = false

      [editor.lsp.inlay-hints]
      enable = true

      [terminal]
      true-color = true

      [keys.insert]
      C-h = "move_char_left"
      C-j = "move_line_down"
      C-k = "move_line_up"
      C-l = "move_char_right"

      [keys.normal]
      A-up = ["extend_to_line_bounds", "delete_selection", "move_line_up", "paste_before"]
      A-k = ["extend_to_line_bounds", "delete_selection", "move_line_up", "paste_before"]
      A-down = ["extend_to_line_bounds", "delete_selection", "paste_after"]
      A-j = ["extend_to_line_bounds", "delete_selection", "paste_after"]
    '';

    xdg.configFile."mitos/languages.toml".text = ''
      [language-server.typescript-language-server]
      command = "${lib.getExe pkgs.typescript-language-server}"
      args = ["--stdio"]

      [language-server.typescript-language-server.config]
      hostInfo = "mitos"

      [language-server.biome]
      command = "${lib.getExe pkgs.biome}"
      args = ["lsp-proxy"]

      [language-server.vscode-html-language-server]
      command = "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server"
      args = ["--stdio"]

      [language-server.vscode-css-language-server]
      command = "${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server"
      args = ["--stdio"]

      [language-server.vscode-json-language-server]
      command = "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server"
      args = ["--stdio"]

      [language-server.nil]
      command = "${lib.getExe pkgs.nil}"

      [language-server.ruff]
      command = "${lib.getExe pkgs.ruff}"
      args = ["server"]

      [language-server.basedpyright]
      command = "${pkgs.basedpyright}/bin/basedpyright-langserver"

      [language-server.taplo]
      command = "${lib.getExe pkgs.taplo}"
      args = ["lsp", "stdio"]

      [language-server.yaml-language-server]
      command = "${lib.getExe pkgs.yaml-language-server}"
      args = ["--stdio"]

      [language-server.marksman]
      command = "${lib.getExe pkgs.marksman}"
      args = ["server"]

      [language-server.bash-language-server]
      command = "${lib.getExe pkgs.bash-language-server}"
      args = ["start"]

      [language-server.tailwindcss-ls]
      command = "${lib.getExe pkgs.tailwindcss-language-server}"
      args = ["--stdio"]

      [[language]]
      name = "typescript"
      auto-format = true
      language-servers = [
        { name = "typescript-language-server", except-features = ["format"] },
        "biome",
      ]

      [[language]]
      name = "javascript"
      auto-format = true
      language-servers = [
        { name = "typescript-language-server", except-features = ["format"] },
        "biome",
      ]

      [[language]]
      name = "tsx"
      auto-format = true
      language-servers = [
        { name = "typescript-language-server", except-features = ["format"] },
        "tailwindcss-ls",
        "biome",
      ]

      [[language]]
      name = "jsx"
      auto-format = true
      language-servers = [
        { name = "typescript-language-server", except-features = ["format"] },
        "tailwindcss-ls",
        "biome",
      ]

      [[language]]
      name = "json"
      auto-format = true
      language-servers = [
        { name = "vscode-json-language-server", except-features = ["format"] },
        "biome",
      ]

      [[language]]
      name = "css"
      auto-format = true
      language-servers = [
        { name = "vscode-css-language-server", except-features = ["format"] },
        "tailwindcss-ls",
        "biome",
      ]

      [[language]]
      name = "html"
      auto-format = true
      language-servers = ["vscode-html-language-server", "tailwindcss-ls"]

      [[language]]
      name = "nix"
      auto-format = true
      language-servers = ["nil"]
      formatter = { command = "${lib.getExe inputs.alejandra.defaultPackage.${system}}" }

      [[language]]
      name = "python"
      auto-format = true
      language-servers = ["ruff", "basedpyright"]

      [[language]]
      name = "toml"
      auto-format = true
      language-servers = ["taplo"]
      formatter = { command = "${lib.getExe pkgs.taplo}", args = ["fmt", "-"] }

      [[language]]
      name = "yaml"
      auto-format = true
      language-servers = ["yaml-language-server"]

      [[language]]
      name = "markdown"
      auto-format = true
      language-servers = ["marksman"]

      [[language]]
      name = "bash"
      auto-format = true
      language-servers = ["bash-language-server"]
      formatter = { command = "${lib.getExe pkgs.shfmt}", args = ["-i", "2"] }
    '';

    xdg.configFile."mitos/ignore".text = ''
      node_modules/
      target/
      dist/
      build/
      out/
      venv/
      tmp/
      __pycache__/
      coverage/
      logs/
      *.log
      .next/
      .vercel/
      .turbo/
      .cache/
      !.env
      !.env.*
      !.envrc
    '';

    xdg.configFile."mitos/themes/stylix.toml".text = ''
      "ui.background" = { bg = "#${colors.base00}" }
      "ui.virtual.whitespace" = "#${colors.base03}"
      "ui.virtual.jump-label" = { fg = "#${colors.base0D}", modifiers = ["bold", "underlined"] }
      "ui.menu" = { fg = "#${colors.base05}", bg = "#${colors.base01}" }
      "ui.menu.selected" = { fg = "#${colors.base01}", bg = "#${colors.base04}" }
      "ui.linenr" = { fg = "#${colors.base03}", bg = "#${colors.base01}" }
      "ui.popup" = { bg = "#${colors.base01}" }
      "ui.window" = { bg = "#${colors.base01}" }
      "ui.linenr.selected" = { fg = "#${colors.base04}", bg = "#${colors.base01}", modifiers = ["bold"] }
      "ui.selection" = { bg = "#${colors.base02}" }
      "comment" = { fg = "#${colors.base03}", modifiers = ["italic"] }
      "ui.statusline" = { fg = "#${colors.base04}", bg = "#${colors.base01}" }
      "ui.cursor" = { fg = "#${colors.base04}", modifiers = ["reversed"] }
      "ui.cursor.primary" = { fg = "#${colors.base05}", modifiers = ["reversed"] }
      "ui.cursor.match" = { fg = "#${colors.base0A}", modifiers = ["underlined"] }
      "ui.text" = "#${colors.base05}"
      "ui.text.focus" = "#${colors.base05}"
      "ui.border" = "#${colors.base03}"
      "ui.help" = { fg = "#${colors.base06}", bg = "#${colors.base01}" }
      "ui.gutter" = { bg = "#${colors.base01}" }
      "ui.bufferline" = { fg = "#${colors.base04}", bg = "#${colors.base00}" }
      "ui.bufferline.active" = { fg = "#${colors.base06}", bg = "#${colors.base01}" }
      "operator" = "#${colors.base05}"
      "variable" = "#${colors.base08}"
      "constant.numeric" = "#${colors.base09}"
      "constant" = "#${colors.base09}"
      "attribute" = "#${colors.base09}"
      "type" = "#${colors.base0A}"
      "string" = "#${colors.base0B}"
      "variable.other.member" = "#${colors.base0B}"
      "constant.character.escape" = "#${colors.base0C}"
      "function" = "#${colors.base0D}"
      "constructor" = "#${colors.base0D}"
      "special" = "#${colors.base0D}"
      "keyword" = "#${colors.base0E}"
      "label" = "#${colors.base0E}"
      "namespace" = "#${colors.base0E}"
      "markup.heading" = "#${colors.base0D}"
      "markup.list" = "#${colors.base08}"
      "markup.bold" = { fg = "#${colors.base0A}", modifiers = ["bold"] }
      "markup.italic" = { fg = "#${colors.base0E}", modifiers = ["italic"] }
      "markup.strikethrough" = { modifiers = ["crossed_out"] }
      "markup.link.url" = { fg = "#${colors.base09}", modifiers = ["underlined"] }
      "markup.link.text" = "#${colors.base08}"
      "markup.quote" = "#${colors.base0C}"
      "markup.raw" = "#${colors.base0B}"
      "diff.plus" = "#${colors.base0B}"
      "diff.delta" = "#${colors.base09}"
      "diff.minus" = "#${colors.base08}"
      "diagnostic" = { modifiers = ["underlined"] }
      "info" = "#${colors.base0D}"
      "hint" = "#${colors.base03}"
      "debug" = "#${colors.base03}"
      "warning" = "#${colors.base09}"
      "error" = "#${colors.base08}"
    '';
  };
}
