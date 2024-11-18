{
  hostname,
  config,
  pkgs,
  host,
  ...
}: {
  programs.zsh = {
    shellAliases = {
      # Utils
      c = "clear";
      cd = "z";
      cat = "bat";
      nano = "micro";
      code =
        if (config.modules.vscodium.enable)
        then "codium"
        else "code";
      diff = "delta --diff-so-fancy --side-by-side";
      less = "bat";
      y = "yazi";
      py = "python";
      ipy = "ipython";
      icat = "kitten icat";
      dsize = "du -hs";
      pdf = "tdf";
      open = "xdg-open";
      space = "ncdu";
      man = "BAT_THEME='default' batman";

      l = "eza --icons  -a --group-directories-first -1"; #EZA_ICON_SPACING=2
      ll = "eza --icons  -a --group-directories-first -1 --no-user --long";
      tree = "eza --icons --tree --group-directories-first";

      # Nixos
      cdnix =
        if (config.modules.vscodium.enable)
        then "cd ~/nixos-config && codium ~/nixos-config"
        else "cd ~/nixos-config && code ~/nixos-config";
      ns = "nom-shell --run zsh";
      nix-switch = "nh os switch";
      nix-update = "nh os switch --update";
      nix-clean = "nh clean all --keep 5";
      nix-search = "nh search";
      nix-test = "nh os test";

      # python
      piv = "python -m venv .venv";
      psv = "source .venv/bin/activate";
    };
  };
}
