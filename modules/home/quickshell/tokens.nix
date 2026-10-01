# Single source for the generated quickshell Colors.qml singleton: consumed by
# default.nix (real Stylix palette) and test/flake.nix's qml-check (stand-in
# palette, also the reference for the drift check against the repo's dev
# copy), so the copies cannot drift unnoticed.
{
  colors, # base00-base0F hex values (no leading #), e.g. config.lib.stylix.colors
  font ? "Maple Mono NF CN",
}: ''
  pragma Singleton
  import Quickshell
  import QtQuick
  Singleton {
    readonly property color base00: "#${colors.base00}";
    readonly property color base01: "#${colors.base01}";
    readonly property color base02: "#${colors.base02}";
    readonly property color base03: "#${colors.base03}";
    readonly property color base04: "#${colors.base04}";
    readonly property color base05: "#${colors.base05}";
    readonly property color base06: "#${colors.base06}";
    readonly property color base07: "#${colors.base07}";
    readonly property color base08: "#${colors.base08}";
    readonly property color base09: "#${colors.base09}";
    readonly property color base0A: "#${colors.base0A}";
    readonly property color base0B: "#${colors.base0B}";
    readonly property color base0C: "#${colors.base0C}";
    readonly property color base0D: "#${colors.base0D}";
    readonly property color base0E: "#${colors.base0E}";
    readonly property color base0F: "#${colors.base0F}";
    readonly property string fontFamily: "${font}";
  }
''
