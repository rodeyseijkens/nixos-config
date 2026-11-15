{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.herdr;
  system = pkgs.stdenv.hostPlatform.system;
  appPackages = inputs.herdr-app.packages.${system};
  codeyRepo = "${config.home.homeDirectory}/Projects/herdr-codey";

  # Mods are not listed here: the activation copies every directory under
  # ${codeyRepo}/mods, so adding or renaming a mod in the repo is enough.
in {
  options.modules.herdr = {
    enable = mkEnableOption "herdr (terminal multiplexer and desktop app)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      # Terminal agent multiplexer.
      pkgs.herdr

      # Desktop app and its core. The app is wrapped with the packaged core
      # on its PATH; herdr-core also puts `hc` in the shell.
      appPackages.herdr-app
      appPackages.herdr-core
    ];

    xdg.configFile."herdr/config.toml".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/herdr/config.toml"
    );

    xdg.configFile."herdr-app/settings.json".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/herdr/settings.json"
    );

    xdg.configFile."herdr-app/keys.json".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${codeyRepo}/keys.json"
    );

    xdg.configFile."herdr-app/themes/gruvb0x.json".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/herdr/themes/gruvb0x.json"
    );

    # Mods and layouts we own are copied, not linked: Herdr draws SVG icons only from
    # real files, and writes gpui-kit.d.ts, jsconfig.json and its image caches into
    # these folders. The codey repo stays the source; generated files are left alone.
    # --checksum because every Nix store file has the same mtime, so size and time
    # alone would miss a same-size edit.
    home.activation.herdrAppOwnedFiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
      appHome="$HOME/.config/herdr-app"
      codeyRepo="${codeyRepo}"
      run ${pkgs.coreutils}/bin/install -d "$appHome/layouts" "$appHome/mods"
      run ${pkgs.coreutils}/bin/install -m 644 "$codeyRepo/layouts/herdr-codey.json" "$appHome/layouts/herdr-codey.json"
      run ${pkgs.coreutils}/bin/install -m 644 "$codeyRepo/layouts/herdr-codey.svg" "$appHome/layouts/herdr-codey.svg"
      # Every directory under the repo's mods/ is installed: no list to maintain.
      for dir in "$codeyRepo"/mods/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        run ${pkgs.rsync}/bin/rsync -rlt --checksum --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
          --exclude gpui-kit.d.ts --exclude herdr.d.ts --exclude jsconfig.json --exclude cache/ \
          "$dir/" "$appHome/mods/$name/"
      done
    '';

    # codey (rodeyseijkens.codey) is installed with the `herdr-install-plugins`
    # helper (see modules/home/scripts/scripts/herdr-install-plugins.sh).
    # The TUI reads ~/.config/codey/config.toml on every start; the herdr plugin
    # pane runs the same binary and inherits it.
    xdg.configFile."codey/config.toml".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/herdr/codey-config.toml"
    );

    # OpenCode server plugin: feeds filetree's Recent tab from OpenCode tool calls,
    # using the same activity file as its Claude Code bridge.
    xdg.configFile."opencode/plugins/herdr-filetree.ts".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${codeyRepo}/integrations/opencode/herdr-filetree.ts"
    );
  };
}
