{inputs, username, host, ...}: {
  imports = [
    ./bat.nix                         # better cat command
    ./bottom.nix                      # resouces monitor
    ./btop.nix                        # resouces monitor 
    ./discord/discord.nix             # discord with gruvbox
    ./fastfetch.nix                   # fetch tool
    ./firefox.nix                      # firefox browser
    ./fzf.nix                         # fuzzy finder
    ./gaming.nix                      # packages related to gaming
    ./git.nix                         # version control
    ./gnome.nix                       # gnome apps
    ./gtk.nix                         # gtk theme
    ./hyprland                        # window manager
    ./kitty.nix                       # terminal
    ./micro.nix                       # nano replacement
    ./nemo.nix                        # file manager
    ./nvim.nix                        # neovim editor
    ./p10k/p10k.nix
    ./packages.nix                    # other packages
    ./rofi.nix                         # launcher
    ./scripts/scripts.nix             # personal scripts
    ./spicetify.nix                   # spotify client
    ./starship.nix                    # shell prompt
    ./swaylock.nix                    # lock screen
    ./swaync/swaync.nix               # notification deamon
    ./swayosd.nix                     # brightness / volume wiget
    ./viewnior.nix                    # image viewer
    ./vscodium.nix                    # vscode fork
    ./waybar                          # status bar
    ./wezterm.nix                     # terminal
    ./xdg-mimes.nix                   # xdg config
    ./zsh                             # shell
  ];
}
