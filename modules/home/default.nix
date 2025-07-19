{...}: {
  imports = [
    ./bat.nix # better cat command
    ./browsers # firefox, zen browser, and google chrome
    ./btop.nix # resouces monitor
    ./cura.nix # 3D printing slicer
    ./fastfetch.nix # fetch tool
    ./fzf.nix # fuzzy finder
    ./ghostty.nix # terminal
    ./git.nix # version control
    ./gnome.nix # gnome apps
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
    ./rofi # launcher
    ./scripts/scripts.nix # personal scripts
    ./spicetify.nix # spotify client
    ./stylix.nix # stylix theme
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
