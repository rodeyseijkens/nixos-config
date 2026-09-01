{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.google-chrome;

  chrome = pkgs.google-chrome.override {
    commandLineArgs = concatStringsSep " " [
      "--enable-features=UseOzonePlatform"
      "--ozone-platform=wayland"
      "--profile-directory=Default"
    ];
  };

  # Launcher: under Hyprland, the first google-chrome window (when no other
  # google-chrome window exists yet) is spawned on cfg.initialSpawnWorkspace. All
  # later windows, and non-Hyprland invocations, start chrome normally.
  launcher = pkgs.writeShellScript "google-chrome-stable" ''
    real_bin="${chrome}/bin/google-chrome-stable"
    workspace="${toString cfg.initialSpawnWorkspace}"

    if [ -n "$workspace" ] &&
      [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] &&
      command -v hyprctl >/dev/null 2>&1 &&
      ! hyprctl clients -j 2>/dev/null | ${pkgs.jq}/bin/jq -e 'any(.class == "google-chrome")' >/dev/null 2>&1; then
      args=""
      for arg in "$@"; do
        args+=" $(printf '%q' "$arg")"
      done
      if hyprctl dispatch exec "[workspace $workspace] $real_bin$args" >/dev/null 2>&1; then
        exit 0
      fi
    fi

    exec "$real_bin" "$@"
  '';
in {
  options.modules.google-chrome = {
    enable = mkEnableOption "google-chrome";

    initialSpawnWorkspace = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Workspace to spawn the first google-chrome window on. Only applies
        when no google-chrome window exists yet; any later window opens on
        the current workspace. Set to null to disable.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.chromium = {
      enable = true;
      package = pkgs.symlinkJoin {
        name = "google-chrome-${chrome.version}";
        paths = [chrome];
        postBuild = ''
          rm -f $out/bin/google-chrome $out/bin/google-chrome-stable
          ln -s ${launcher} $out/bin/google-chrome-stable
          ln -s google-chrome-stable $out/bin/google-chrome

          # desktop entries point at the unwrapped store path, rewrite them
          for f in $out/share/applications/*.desktop; do
            if grep -qF "${chrome}/bin/google-chrome-stable" "$f"; then
              target="$(readlink -f "$f")"
              rm "$f"
              cp "$target" "$f"
              substituteInPlace "$f" \
                --replace-fail "${chrome}/bin/google-chrome-stable" "$out/bin/google-chrome-stable"
            fi
          done
        '';
      };
    };
  };
}
