{...}: {
  imports = [
    ./audio.nix # audio configuration
    ./bat.nix # better cat command
    ./browsers # zen browser, and google chrome
    ./btop.nix # resouces monitor
    ./3d-printing.nix # 3D printing slicers
    ./devpod.nix # devpod development environments
    ./fastfetch.nix # fetch tool
    ./fzf.nix # fuzzy finder
    ./ghostty.nix # terminal
    ./git.nix # version control
    ./gnome.nix # gnome apps
    ./gtk.nix # gtk theme
    ./herdr # terminal agent multiplexer (gruvbox theme)
    ./hyprland # window manager
    ./legcord # discord client with gruvbox
    ./llm # llm tools and plugins
    ./micro.nix # nano replacement
    ./mise # dev tool version manager
    ./mitos.nix # mitos editor
    ./nautilus.nix # file manager
    ./nvim.nix # neovim editor
    ./obs-studio.nix # screen recorder
    ./packages.nix # other packages
    ./quickshell # quickshell shell (bar, notifications, OSD)
    ./spicetify.nix # spotify client
    ./starship.nix # prompt
    ./superfile # file manager with custom Gruvb0x theme
    ./scripts/scripts.nix # personal scripts
    ./spicetify.nix # spotify client
    ./stylix.nix # stylix theme
    ./superwhisper.nix # voice dictation
    ./t3code.nix # t3code
    ./telegram.nix # telegram desktop
    ./tigervnc.nix # remote desktop
    ./tiled.nix # tiled mapeditor
    ./viewnior.nix # image viewer
    ./vscode/vscode.nix # vscode
    ./walker # walker launcher
    ./worktrunk.nix # git worktree management
    ./xdg-mimes.nix # xdg config
    ./zed-editor.nix # zed editor
    ./zsh # shell
  ];
}
