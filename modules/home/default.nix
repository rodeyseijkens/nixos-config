{...}: {
  imports = [
    ./bat.nix # better cat command
    ./btop.nix # resouces monitor
    ./fastfetch.nix # fetch tool
    ./firefox.nix # browser
    ./fzf.nix # fuzzy finder
    ./git.nix # version control
    ./gnome.nix # gnome apps
    ./google-chrome.nix # browser
    ./gtk.nix # gtk theme
    ./hyprland # window manager
    ./kitty.nix # terminal
    ./legcord # discord client with gruvbox
    ./micro.nix # nano replacement
    ./nautilus.nix # file manager
    ./nvim.nix # neovim editor
    ./obs-studio.nix # screen recorder
    ./p10k/p10k.nix # zsh theme
    ./packages.nix # other packages
    ./rofi.nix # launcher
    ./scripts/scripts.nix # personal scripts
    ./spicetify.nix # spotify client
    ./swaync/swaync.nix # notification deamon
    ./swayosd.nix # brightness / volume wiget
    ./tigervnc.nix # remote desktop
    ./viewnior.nix # image viewer
    ./vscode.nix # vscode
    ./waybar # status bar
    ./xdg-mimes.nix # xdg config
    ./zsh # shell
  ];
}
