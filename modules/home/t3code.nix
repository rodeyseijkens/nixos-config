{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.t3code;
  system = pkgs.stdenv.hostPlatform.system;
  versions = import "${inputs.t3code.outPath}/versions.nix";

  # Local override: T3 Code's diff/code syntax is hardcoded to the Pierre
  # palettes and ignores the selected theme. package.nix swaps in the Gruvbox
  # palettes (and Codey's Gruvbox diff accents) during the AppImage extraction.
  t3codeGruvbox = pkgs.callPackage ./t3code-gruvbox/package.nix {
    inherit (versions.stable) version hash;
  };
in {
  options.modules.t3code = {
    enable = mkEnableOption "t3code";
    gruvboxSyntax = mkOption {
      type = types.bool;
      default = true;
      description = "Use Gruvbox colors for T3 Code's diff/code syntax highlighting.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      (
        if cfg.gruvboxSyntax
        then t3codeGruvbox
        else inputs.t3code.packages.${system}.t3code
      )
    ];

    # Kilo only enables its `question` tool for app/cli/desktop/vscode and has
    # no ACP bridge for it. `kilo acp` sets KILO_CLIENT too late, so the ACP
    # session inherits the `cli` default and gets a tool it can never answer.
    xdg.desktopEntries.t3code = {
      name = "T3 Code (Beta)";
      comment = "Control surface for coding agents";
      exec = "env KILO_CLIENT=acp t3code %U";
      icon = "t3code";
      categories = ["Development"];
      settings.StartupWMClass = "t3code";
    };
  };
}
