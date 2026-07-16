{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.helix-editor;
in {
  options.modules.helix-editor = {enable = mkEnableOption "helix-editor";};
  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;
      defaultEditor = true;
      settings.editor = {
        cursorline = true;
        true-color = true;
        auto-format = true;
        indent-guides.render = true;
        file-picker.hidden = true;
        lsp.display-inlay-hints = true;
      };

      extraPackages = with pkgs; [
        typescript-language-server
        typescript
        biome
        vscode-langservers-extracted
        nil
        alejandra
        ruff
        basedpyright
        taplo
        yaml-language-server
        marksman
        bash-language-server
        shfmt
        tailwindcss-language-server
      ];

      languages.language-server = {
        typescript-language-server = {
          command = lib.getExe pkgs.typescript-language-server;
          args = ["--stdio"];
          config.hostInfo = "helix";
        };

        biome = {
          command = lib.getExe pkgs.biome;
          args = ["lsp-proxy"];
        };

        vscode-html-language-server = {
          command = "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server";
          args = ["--stdio"];
        };

        vscode-css-language-server = {
          command = "${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server";
          args = ["--stdio"];
        };

        vscode-json-language-server = {
          command = "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server";
          args = ["--stdio"];
        };

        nil = {
          command = lib.getExe pkgs.nil;
        };

        ruff = {
          command = lib.getExe pkgs.ruff;
          args = ["server"];
        };

        basedpyright = {
          command = "${pkgs.basedpyright}/bin/basedpyright-langserver";
        };

        taplo = {
          command = lib.getExe pkgs.taplo;
          args = ["lsp" "stdio"];
        };

        yaml-language-server = {
          command = lib.getExe pkgs.yaml-language-server;
          args = ["--stdio"];
        };

        marksman = {
          command = lib.getExe pkgs.marksman;
          args = ["server"];
        };

        bash-language-server = {
          command = lib.getExe pkgs.bash-language-server;
          args = ["start"];
        };

        tailwindcss-ls = {
          command = lib.getExe pkgs.tailwindcss-language-server;
          args = ["--stdio"];
        };
      };

      languages.language = [
        {
          name = "typescript";
          auto-format = true;
          language-servers = [
            {name = "typescript-language-server"; except-features = ["format"];}
            "biome"
          ];
        }
        {
          name = "javascript";
          auto-format = true;
          language-servers = [
            {name = "typescript-language-server"; except-features = ["format"];}
            "biome"
          ];
        }
        {
          name = "tsx";
          auto-format = true;
          language-servers = [
            {name = "typescript-language-server"; except-features = ["format"];}
            "tailwindcss-ls"
            "biome"
          ];
        }
        {
          name = "jsx";
          auto-format = true;
          language-servers = [
            {name = "typescript-language-server"; except-features = ["format"];}
            "tailwindcss-ls"
            "biome"
          ];
        }
        {
          name = "json";
          auto-format = true;
          language-servers = [
            {name = "vscode-json-language-server"; except-features = ["format"];}
            "biome"
          ];
        }
        {
          name = "css";
          auto-format = true;
          language-servers = [
            {name = "vscode-css-language-server"; except-features = ["format"];}
            "tailwindcss-ls"
            "biome"
          ];
        }
        {
          name = "html";
          auto-format = true;
          language-servers = ["vscode-html-language-server" "tailwindcss-ls"];
        }
        {
          name = "nix";
          auto-format = true;
          language-servers = ["nil"];
          formatter = {
            command = lib.getExe pkgs.alejandra;
          };
        }
        {
          name = "python";
          auto-format = true;
          language-servers = ["ruff" "basedpyright"];
        }
        {
          name = "toml";
          auto-format = true;
          language-servers = ["taplo"];
          formatter = {
            command = lib.getExe pkgs.taplo;
            args = ["fmt" "-"];
          };
        }
        {
          name = "yaml";
          auto-format = true;
          language-servers = ["yaml-language-server"];
        }
        {
          name = "markdown";
          auto-format = true;
          language-servers = ["marksman"];
        }
        {
          name = "bash";
          auto-format = true;
          language-servers = ["bash-language-server"];
          formatter = {
            command = lib.getExe pkgs.shfmt;
            args = ["-i" "2"];
          };
        }
      ];
    };
  };
}
