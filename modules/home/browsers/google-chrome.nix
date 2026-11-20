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
      # Dawn (WebGPU) cannot open the NVIDIA Vulkan ICD from the sandboxed GPU
      # process, so WebGPU silently falls back to the slow OpenGL compatibility
      # path (~100fps with stutters). Without the sandbox Dawn uses Vulkan and
      # runs at the full refresh rate (165fps, no stutter on an RTX 3080).
      "--disable-gpu-sandbox"
    ];
  };

  # NixOS keeps Vulkan ICDs in /run/opengl-driver, which the Vulkan loader does
  # not scan by default, and the session environment does not export
  # VK_ICD_FILENAMES. Point the loader at the NVIDIA ICD so Dawn can use Vulkan.
  chromeVulkan = pkgs.writeShellScript "google-chrome-vulkan" ''
    export VK_ICD_FILENAMES="/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json"
    export VK_DRIVER_FILES="/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json"
    exec "${chrome}/bin/google-chrome-stable" "$@"
  '';

  # Launcher: under Hyprland, the first google-chrome window (when no other
  # google-chrome window exists yet) is spawned on cfg.initialSpawnWorkspace. All
  # later windows, and non-Hyprland invocations, start chrome normally.
  launcher = pkgs.writeShellScript "google-chrome-stable" ''
    real_bin="${chromeVulkan}"
    workspace="${toString cfg.initialSpawnWorkspace}"

    if [ -n "$workspace" ] &&
      [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] &&
      command -v hyprctl >/dev/null 2>&1 &&
      ! hyprctl clients -j 2>/dev/null | ${pkgs.jq}/bin/jq -e 'any(.class == "google-chrome")' >/dev/null 2>&1; then
      args=""
      for arg in "$@"; do
        args+=" $(printf '%q' "$arg")"
      done
      cmd="$real_bin$args"
      if hyprctl dispatch "hl.dsp.exec_cmd('$cmd', { workspace = '$workspace' })" >/dev/null 2>&1; then
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
