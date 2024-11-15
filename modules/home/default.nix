{
  ...
}: {
  imports = [
    ./bat.nix               # better cat command
    ./bottom.nix            # resouces monitor
    ./btop.nix              # resouces monitor
    ./fastfetch.nix         # fetch tool
    ./firefox.nix           # browser
    ./fzf.nix               # fuzzy finder
    ./git.nix               # version control
    ./gnome.nix             # gnome apps
    ./gtk.nix               # gtk theme
    ./hyprland              # window manager
    ./kitty.nix             # terminal
    ./micro.nix             # nano replacement
    ./nemo.nix              # file manager
    ./nvim.nix              # neovim editor
    ./p10k/p10k.nix         # zsh theme
    ./packages.nix          # other packages
    ./rofi.nix              # launcher
    ./scripts/scripts.nix   # personal scripts
    ./spicetify.nix         # spotify client
    ./swaync/swaync.nix     # notification deamon
    ./swayosd.nix           # brightness / volume wiget
    ./viewnior.nix          # image viewer
    ./vscodium.nix          # vscode fork
    ./waybar                # status bar
    ./webcord               # discord client with gruvbox
    ./xdg-mimes.nix         # xdg config
    ./zsh                   # shell
  ];
}
