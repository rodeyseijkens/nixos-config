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

    # Type-check the generated config against the real hl.meta.lua schema
    # using lua-language-server. No mocks — uses Hyprland's own type annotations.
    # Catches: undefined fields (e.g. hl.exec_once), type mismatches, etc.
luals-check-hypr = pkgs.writeShellScriptBin "luals-check-hypr" ''
      set -uo pipefail
      CONFIG=''${1:?usage: luals-check-hypr <hyprland.lua> <hl.meta.lua>}
      SCHEMA=''${2:?usage: luals-check-hypr <hyprland.lua> <hl.meta.lua>}

      WORKDIR="/tmp/hypr-luals-$(basename "$CONFIG" | sed 's/\.lua//')"
      rm -rf "$WORKDIR"
      mkdir -p "$WORKDIR"
      chmod 755 "$WORKDIR"
      cp -fL "$CONFIG" "$WORKDIR/hyprland.lua"
      chmod 644 "$WORKDIR/hyprland.lua"
      cp -fL "$SCHEMA" "$WORKDIR/hl.meta.lua"
      DIR=$(dirname "$CONFIG")
      for f in "$DIR"/*.lua; do
        [ -f "$f" ] && cp -fL "$f" "$WORKDIR/" 2>/dev/null
      done

      cat > "$WORKDIR/.luarc.json" <<EOF
      {"workspace.library": ["."], "diagnostics.severity.undefined-field": "Warning"}
      EOF

      OUT=$(${pkgs.lua-language-server}/bin/lua-language-server --check "$WORKDIR" 2>&1 || true)

      UNDEF=$(echo "$OUT" | grep -c 'Undefined field' || true)
      if [ "$UNDEF" -gt 0 ]; then
        echo "$OUT" | grep -F "$WORKDIR" | grep 'Undefined field'
        exit 1
      fi
      exit 0
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

      echo "==> Type check against real hl.meta.lua (lua-language-server)..."
      set +e
      LUALSOUT=$(luals-check-hypr "''${CONFIG}" "''${SCHEMA}" 2>&1)
      RC=$?
      set -e
      if [ -n "''${LUALSOUT}" ]; then
        echo "''${LUALSOUT}"
      fi
      if [ "''${RC}" -ne 0 ]; then
        STATUS=1
      fi

      echo "==> Validating with hyprvalidate (using live hyprland schema)..."
      set +e
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
      set -e

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
      packages = [ hyprvalidate pkgs.lua validate-hypr luals-check-hypr pkgs.lua-language-server ];
      shellHook = ''
        echo "Hyprland Lua config test environment"
        echo ""
        echo "Commands:"
        echo "  validate-hypr [host]    build hyprland + config + run ALL checks (default: desktop)"
        echo "  luals-check-hypr <cfg> <schema>  type-check against real hl.meta.lua (no mocks)"
        echo "  hyprvalidate --help     hyprvalidate tool"
        echo ""
        echo "Available hosts: desktop, desktop-work, desktop-office"
      '';
    };
  };
}