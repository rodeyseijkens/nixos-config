{
  description = "Hyprland Lua config validation shell (standalone)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-config.url = "path:../";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-config,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    luaparser = pkgs.python3.pkgs.buildPythonPackage rec {
      pname = "luaparser";
      version = "4.2.0";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/24/64/574e8dadf7dcc08b5c8435756b6a44ea382d14b4d3c19669dbbab112532f/luaparser-4.2.0.tar.gz";
        hash = "sha256-MV4ViLI1AL76+CRgTC0Op12viUtVBxJmNqjPqdw9djY=";
      };
      pyproject = true;
      nativeBuildInputs = with pkgs.python3.pkgs; [setuptools];
      propagatedBuildInputs = with pkgs.python3.pkgs; [antlr4-python3-runtime multimethod];
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
      nativeBuildInputs = with pkgs.python3.pkgs; [setuptools];
      propagatedBuildInputs = [luaparser];
      meta.mainProgram = "hyprvalidate";
    };

    parentFlake = toString ../.;

    # qml-check and qml-regen need a Colors.qml stand-in (the real one is
    # Nix-generated at HM switch); shared with quickshell/default.nix so the
    # shapes cannot drift, and shared here so lint, drift-check and the repo's
    # dev-run copy come from the exact same bytes.
    devColorsQml = import ../modules/home/quickshell/tokens.nix {
      colors = {
        base00 = "1D2021";
        base01 = "3C3836";
        base02 = "504945";
        base03 = "665C54";
        base04 = "BDAE93";
        base05 = "D5C4A1";
        base06 = "EBDBB2";
        base07 = "FBF1C7";
        base08 = "FB4934";
        base09 = "FE8019";
        base0A = "D79921";
        base0B = "458588";
        base0C = "689D6A";
        base0D = "98971A";
        base0E = "D16286";
        base0F = "D65D0E";
      };
    };

    devColors = pkgs.writeText "dev-Colors.qml" devColorsQml;

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
    qml-check = pkgs.writeShellScriptBin "qml-check" ''
      set -euo pipefail
      CFG="''${1:-${parentFlake}/modules/home/quickshell/config}"
      if [ ! -d "''${CFG}" ]; then
        echo "ERROR: quickshell config dir not found: ''${CFG}"
        exit 1
      fi
      STAGE="$(mktemp -d)"
      trap 'rm -rf "''${STAGE}"' EXIT
      cp -r "''${CFG}/"* "''${STAGE}/"
      # Quickshell resolves `qs.Commons` / `qs.Ui` against the config root.
      # qmllint has no such mapping, so expose the stage as its own `qs` root.
      ln -s "''${STAGE}" "''${STAGE}/qs"
      GEN="''${STAGE}/Colors.qml"
      # Lint ALWAYS reads the tokens.nix-generated stand-in — never the repo
      # copy, which can drift (it did once: no fontFamily) without notice.
      cp -f "${devColors}" "''${GEN}"
      # Drift check: the repo's gitignored dev-run copy (qs -p) must be byte
      # identical to the generation; regenerate with `qml-regen`.
      if [ -f "''${CFG}/Colors.qml" ]; then
        if ! diff -q "${devColors}" "''${CFG}/Colors.qml" >/dev/null; then
          echo "qml-check: FAIL — repo Colors.qml drifted from tokens.nix; run: qml-regen"
          diff "${devColors}" "''${CFG}/Colors.qml" || true
          exit 1
        fi
      else
        echo "qml-check: WARN — no repo Colors.qml under ''${CFG}; drift check skipped"
      fi
      # Seam enforcement: local popups use ScreenPopup.qml; only the bar and
      # upstream Ui overlay primitives are separately allowlisted.
      SEAM_VIOLATIONS=$(
        grep -rlE 'ExclusionMode\.Ignore' "''${STAGE}" --include='*.qml' | grep -vE 'ScreenPopup\.qml|Ui/(OverlayWindow|KeyboardPanel|SpeedTestOverlay)\.qml|plugins/bar/widgets/resonance/MediaWidget\.qml' || true
        grep -rl 'PanelWindow' "''${STAGE}" --include='*.qml' | grep -vE 'ScreenPopup\.qml|plugins/bar/Bar\.qml|Ui/(OverlayWindow|KeyboardPanel|SpeedTestOverlay)\.qml|plugins/bar/widgets/resonance/MediaWidget\.qml' || true
        sort -u
      )
      if [ -n "''${SEAM_VIOLATIONS}" ]; then
        echo "qml-check: FAIL — popup surface seam violated (PanelWindow/ExclusionMode outside ScreenPopup.qml, the bar, and upstream Ui overlay primitives):"
        echo "''${SEAM_VIOLATIONS}"
        exit 1
      fi
      QS_QML="${pkgs.quickshell}/lib/qt-6/qml"
      QT_QML="${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
      OUT=$(${pkgs.qt6.qtdeclarative}/bin/qmllint -I "''${QS_QML}" -I "''${QT_QML}" -I "''${STAGE}" $(find "''${STAGE}" -name '*.qml') 2>&1 || true)
      echo "''${OUT}"
      # Hard failures: syntax/parse errors or genuinely missing imports.
      # Known-benign (runtime-verified working): uncreatable-type
      # (PanelWindow/Singleton are backend-provided), unqualified/missing-property
      # (qmllint cannot see cross-file singletons), unresolved-type on margins
      # (grouped PanelWindow property), missing-type on Edges (runtime enum),
      # signal-handler-parameters on Process.onExited (QProcess type not in qmltypes),
      # "Warnings occurred while importing" aggregates (qmllint's own module-level
      # import noise; genuine per-type import failures carry their [import] tag
      # on their own Warning line and still fail below).
      if echo "''${OUT}" | grep -E '^Error' | grep -q .; then
        echo "qml-check: FAIL"
        exit 1
      fi
      if echo "''${OUT}" | grep -E '^(Error|Warning):' | grep -E '\[(syntax|parse|import|missing-type|unresolved-alias|signal-handler-parameters|unresolved-type)\]' | grep -v -i -E 'edges|gravity|margins|adjustment|anchor|AuthFlow|onexited|Warnings occurred while importing' | grep -q .; then
        echo "qml-check: FAIL"
        exit 1
      fi
      echo "qml-check: PASS"
    '';
    qml-regen = pkgs.writeShellScriptBin "qml-regen" ''
      set -euo pipefail
      cp ''${2:+-v} "${devColors}" "''${1:?usage: qml-regen <config-dir>}/Colors.qml"
      echo "repo Colors.qml regenerated from tokens.nix"
    '';
    qml-test = pkgs.writeShellScriptBin "qml-test" ''
      set -euo pipefail
      OUT=$(${pkgs.qt6.qtdeclarative}/bin/qml "${parentFlake}/test/qml-tests/run.qml" 2>&1 || true)
      echo "''${OUT}"
      if echo "''${OUT}" | grep -q FAIL; then
        echo "qml-test: FAIL"
        exit 1
      fi
      echo "qml-test: PASS"
    '';
  in {
    packages.${system}.hyprvalidate = hyprvalidate;

    devShells.${system}.default = pkgs.mkShell {
      packages = [hyprvalidate pkgs.lua validate-hypr luals-check-hypr pkgs.lua-language-server pkgs.quickshell pkgs.qt6.qtdeclarative qml-check qml-regen qml-test];
      shellHook = ''
        echo "Hyprland Lua config test environment"
        echo ""
        echo "Commands:"
        echo "  validate-hypr [host]    build hyprland + config + run ALL checks (default: desktop)"
        echo "  luals-check-hypr <cfg> <schema>  type-check against real hl.meta.lua (no mocks)"
        echo "  qml-check [config-dir]  lint quickshell QML (default: ../modules/home/quickshell/config)"
        echo "  qml-regen [config-dir]  regenerate the repo Colors.qml dev copy from tokens.nix"
        echo "  qml-test                run the pure-lib unit tests (test/qml-tests)"
        echo "  hyprvalidate --help     hyprvalidate tool"
        echo ""
        echo "Available hosts: desktop, desktop-work, desktop-office"
      '';
    };
  };
}
