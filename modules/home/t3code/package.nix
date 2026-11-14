{
  lib,
  pkgs,
  pname ? "t3code",
  version,
  hash,
}: let
  src = pkgs.fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    inherit hash;
  };

  # Upstream hardcodes syntax highlighting to the Pierre palettes, so the diff
  # and code views ignore the selected (Gruvbox) app theme. This swaps the
  # bundled Pierre palettes for the Gruvbox ones that ship with the app.
  appimageContents = pkgs.appimageTools.extract {
    inherit pname version src;

    postExtract = ''
      chmod u+w $out/resources/app.asar
      ${pkgs.python3}/bin/python3 ${./patch.py} $out/resources/app.asar
    '';
  };
in
  pkgs.appimageTools.wrapAppImage {
    inherit pname version;
    contents = appimageContents;

    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/t3code.desktop $out/share/applications/${pname}.desktop
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace 'Exec=AppRun' 'Exec=${pname}'
      cp -r ${appimageContents}/usr/share/icons $out/share

      if [ "${pname}" != "t3code" ]; then
        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace 'Icon=t3code' 'Icon=${pname}'
        chmod -R u+w $out/share/icons
        find $out/share/icons -name 't3code.png' -execdir mv {} '${pname}.png' \;
      fi
    '';

    extraBwrapArgs = [
      "--bind-try /etc/nixos/ /etc/nixos/"
    ];

    dieWithParent = false;

    extraPkgs = pkgs:
      with pkgs; [
        autoPatchelfHook
      ];
  }
