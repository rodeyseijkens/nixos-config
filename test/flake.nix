{
  description = "Hyprland Lua config validation shell (standalone)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-config.url = "path:../";
  };

  outputs = { self, nixpkgs, nixos-config, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

    luaparser = pkgs.python3.pkgs.buildPythonPackage rec {
      pname = "luaparser";
      version = "4.2.0";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/24/64/574e8dadf7dcc08b5c8435756b6a44ea382d14b4d3c19669dbbab112532f/luaparser-4.2.0.tar.gz";
        hash = "sha256-MV4ViLI1AL76+CRgTC0Op12viUtVBxJmNqjPqdw9djY=";
      };
      pyproject = true;
      nativeBuildInputs = with pkgs.python3.pkgs; [ setuptools ];
      propagatedBuildInputs = with pkgs.python3.pkgs; [ antlr4-python3-runtime multimethod ];
      meta.description = "Lua parser and AST builder in Python";
    };

    hyprvalidate = pkgs.python3.pkgs.buildPythonApplication rec {
      pname = "hyprvalidate";
      version = "0.3.0";
      src = pkgs.fetchFromGitHub {
        owner = "Paritsingla7";
        repo = "hyprvalidate";
        rev = "f2f325faa461d28d75387be34313d02299fc62a0";
        hash = "sha256-YV1Zljaio+n03888VkAQn3By+9/Nrfj50+DUtFR//gM=";
      };
      pyproject = true;
      nativeBuildInputs = with pkgs.python3.pkgs; [ setuptools ];
      propagatedBuildInputs = [ luaparser ];
      meta.mainProgram = "hyprvalidate";
    };

    parentFlake = toString ../.;

    check-hypr = pkgs.writeShellScriptBin "check-hypr" ''
      set -euo pipefail
      CONFIG=''${1:?usage: check-hypr <hyprland.lua>}
      exec ${pkgs.lua}/bin/lua ${./check-hypr.lua} "''${CONFIG}"
    '';

    validate-hypr = pkgs.writeShellScriptBin "validate-hypr" ''
      set -euo pipefail
      HOST=''${1:-desktop}
      USER="rodey"
      OUTDIR="/tmp/hyprvalidate-''${HOST}"
      mkdir -p "''${OUTDIR}"
      echo "==> Building hyprland package (for schema) and config for host: ''${HOST}"
      nix build "${parentFlake}#nixosConfigurations.''${HOST}.config.programs.hyprland.package" \
        --out-link "''${OUTDIR}/hyprland" 2>&1
      SCHEMA="''${OUTDIR}/hyprland/share/hypr/stubs/hl.meta.lua"
      if [ ! -f "''${SCHEMA}" ]; then
        echo "ERROR: no hl.meta.lua found in hyprland package"
        exit 1
      fi
      echo "==> Building home-manager activation for host: ''${HOST}"
      nix build "${parentFlake}#nixosConfigurations.''${HOST}.config.home-manager.users.''${USER}.home.activationPackage" \
        --out-link "''${OUTDIR}/activation" 2>&1
      CONFIG_DIR="''${OUTDIR}/activation/home-files/.config/hypr"
      if [ ! -d "''${CONFIG_DIR}" ]; then
        echo "ERROR: hyprland config not found at ''${CONFIG_DIR}"
        exit 1
      fi
      CONFIG="''${CONFIG_DIR}/hyprland.lua"

      STATUS=0

      echo "==> Runtime check (arity/type against real hl API)..."
      if ! check-hypr "''${CONFIG}"; then
        STATUS=1
      fi

      echo "==> Validating with hyprvalidate (using live hyprland schema)..."
      # Filter known false positives from schema gaps:
      #   animations.animation, animations.bezier — vararg directives not in flat key space
      #   workspace — valid config key, missing from HL.ConfigOpt stub
      ISSUES=$(hyprvalidate check "''${CONFIG_DIR}" --stub "''${SCHEMA}" 2>&1 \
        | grep "\[" \
        | grep -v "'animations\\.animation' is not a known" \
        | grep -v "'animations\\.bezier' is not a known" \
        | grep -v "'workspace' is not a known" \
        || true)
      if [ -n "''${ISSUES}" ]; then
        echo "''${ISSUES}"
        STATUS=1
      fi

      if [ "''${STATUS}" -eq 0 ]; then
        echo ""
        echo "All checks passed."
      else
        echo ""
        echo "Checks failed."
      fi
      echo ""
      echo "Config:  file://''${CONFIG}"
      echo "Schema:  file://''${SCHEMA}"
      exit "''${STATUS}"
    '';
  in {
    packages.${system}.hyprvalidate = hyprvalidate;

    devShells.${system}.default = pkgs.mkShell {
      packages = [ hyprvalidate pkgs.lua validate-hypr check-hypr ];
      shellHook = ''
        echo "Hyprland Lua config test environment"
        echo ""
        echo "Commands:"
        echo "  validate-hypr [host]   build hyprland + config + run both checks (default: desktop)"
        echo "  check-hypr <file>      runtime arity/type check against the real hl API"
        echo "  hyprvalidate --help    hyprvalidate tool"
        echo "  luac -p <file>         Lua syntax check"
        echo ""
        echo "Available hosts: desktop, desktop-work, desktop-office"
      '';
    };
  };
}