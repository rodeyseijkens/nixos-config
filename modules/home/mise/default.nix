{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
  };

  xdg.configFile."mise/config.toml".source = lib.mkForce (
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/mise/config.toml"
  );

  # clickup (installed via mise) ships a cobra-generated zsh completion.
  # mise activation runs at the very end of .zshrc, so clickup is not on PATH
  # when initContent runs; generate the completion lazily on first Tab instead.
  programs.zsh.initContent = ''
    _clickup_lazy_complete() {
      if ! (( $+functions[_clickup] )); then
        source <(command clickup completion zsh)
      fi
      _clickup "$@"
    }
    if (( $+functions[compdef] )); then
      compdef _clickup_lazy_complete clickup
    fi
  '';
}
