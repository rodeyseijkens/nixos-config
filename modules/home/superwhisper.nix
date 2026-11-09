{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.superwhisper;

  superwhisper = pkgs.stdenv.mkDerivation {
    pname = "superwhisper";
    version = "1.2.0";

    src = pkgs.fetchurl {
      url = "https://github.com/superultrainc/superwhisper-linux-releases/releases/download/v1.2.0/superwhisper-linux-x86_64-1.2.0.tar.zst";
      hash = "sha256-KLxXWO1s9CRouX75QOwqlrEU5rbqA7yywEvGeIV9AvA=";
    };
    sourceRoot = "source";

    unpackPhase = ''
      runHook preUnpack
      mkdir -p source
      tar --zstd -xf "$src" -C source --strip-components=1
      runHook postUnpack
    '';

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.zstd
      pkgs.makeWrapper
      pkgs.wrapGAppsHook4
      pkgs.gobject-introspection
      pkgs.python3
    ];

    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.gtk4
      pkgs.gtk4-layer-shell
      pkgs.at-spi2-core
      pkgs.librsvg
      pkgs.gdk-pixbuf
      pkgs.fontconfig
      pkgs.vulkan-loader
      pkgs.wayland
      pkgs.libglvnd
      pkgs.libnotify
      pkgs.pulseaudio
      pkgs.libxkbcommon
      pkgs.openssl
      pkgs.zlib
      pkgs.zstd
    ];

    autoPatchelfIgnoreMissingDeps = [
      "libFcitx5Core.so.7"
      "libFcitx5Utils.so.2"
    ];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/superwhisper $out/bin
      cp -a . $out/share/superwhisper/
      makeWrapper $out/share/superwhisper/app/run.sh $out/bin/superwhisper
      runHook postInstall
    '';

    preFixup = ''
      gappsWrapperArgs+=(
        --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          pkgs.gtk4-layer-shell
          pkgs.vulkan-loader
          pkgs.wayland
          pkgs.libglvnd
        ]
      }
        --prefix PATH : ${
        lib.makeBinPath [
          (pkgs.python3.withPackages (ps: [
            ps.pygobject3
            ps.pycairo
          ]))
          pkgs.wl-clipboard
          pkgs.ffmpeg
          pkgs.libnotify
          pkgs.pulseaudio
          pkgs.xdg-utils
          pkgs.coreutils
          pkgs.systemd
        ]
      }
      )
    '';

    meta = {
      description = "Local and cloud voice dictation";
      homepage = "https://superwhisper.com/linux";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "superwhisper";
    };
  };
in {
  options.modules.superwhisper = {enable = mkEnableOption "superwhisper";};

  config = mkIf cfg.enable {
    home.packages = [superwhisper];

    systemd.user.services.superwhisper = {
      Unit = {
        Description = "Superwhisper dictation";
        After = ["graphical-session.target" "pipewire.service"];
        PartOf = ["graphical-session.target"];
        Conflicts = ["superwhisper-dev.service"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${superwhisper}/bin/superwhisper daemon";
        ExecStopPost = [
          "${superwhisper}/bin/superwhisper playback-restore"
          "${superwhisper}/bin/superwhisper desktop-release"
        ];
        Restart = "on-failure";
        RestartSec = 2;
        KillMode = "control-group";
        TimeoutStopSec = 15;
        UMask = "0077";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
