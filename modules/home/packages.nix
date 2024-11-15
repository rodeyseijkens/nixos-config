{ inputs, pkgs, ... }: 
let 
  _2048 = pkgs.callPackage ../../pkgs/2048/default.nix {}; 
in
{
  home.packages = (with pkgs; [
    _2048
    _2048-in-terminal
    vitetris
    nethack

    ## CLI utility
    ani-cli
    bitwise                           # cli tool for bit / hex manipulation
    caligula                          # User-friendly, lightweight TUI for disk imaging
    dconf-editor
    docfd                             # TUI multiline fuzzy document finder
    eza                               # ls replacement
    entr                              # perform action when file change
    fd                                # find replacement
    ffmpeg
    file                              # Show file information 
    gtt                               # google translate TUI
    gifsicle                          # gif utility
    gtrash                            # rm replacement, put deleted files in system trash
    hexdump
    imv                               # image viewer
    jq                                # JSON processor
    killall
    lazygit
    libnotify
	  man-pages					            	  # extra man pages
    mimeo
    mpv                               # video player
    ncdu                              # disk space
    nitch                             # systhem fetch util
    openssl
    onefetch                          # fetch utility for git repo
    pamixer                           # pulseaudio command line mixer
    playerctl                         # controller for media players
    ripgrep                           # grep replacement
    swappy                            # snapshot editing tool
    tldr                              # tldr.sh
    unzip
    wl-clipboard                      # clipboard utils for wayland (wl-copy, wl-paste)
    wget
    yazi                              # terminal file manager
    yt-dlp-light
    xdg-utils
    xxd

    ## CLI 
    cbonsai                           # terminal screensaver
    cmatrix
    pipes                             # terminal screensaver
    sl
    tty-clock                         # cli clock

    ## GUI Apps
    bleachbit                         # cache cleaner
    nix-prefetch-github
    pavucontrol                       # pulseaudio volume controle (GUI)
    vlc
    winetricks
    wineWowPackages.wayland
    zenity                            # simple dialog creator

    # C / C++
    gcc
    gdb
    gnumake

    # Python
    python3
    python312Packages.ipython

    inputs.alejandra.defaultPackage.${system}
  ]);
}
