{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    ## CLI utility
    dconf-editor
    entr # perform action when file change
    eza # ls replacement
    fd # find replacement
    ffmpeg
    file # Show file information
    gifsicle # gif utility
    gtrash # rm replacement, put deleted files in system trash
    imv # image viewer
    killall
    lazygit
    libnotify
    man-pages # extra man pages
    mimeo
    mpv # video player
    ncdu # disk space
    nitch # systhem fetch util
    nix-prefetch-github
    openssl
    pamixer # pulseaudio command line mixer
    playerctl # controller for media players
    swappy # snapshot editing tool
    unzip
    wget
    wl-clipboard # clipboard utils for wayland (wl-copy, wl-paste)
    xdg-utils
    xxd
    yazi # terminal file manager
    yt-dlp-light # audio/video downloader
    zenity # simple dialog creator

    ## CLI fun
    cbonsai # terminal screensaver
    cmatrix
    pipes # terminal screensaver
    sl
    tty-clock # cli clock

    ## GUI Apps
    bleachbit # cache cleaner
    pavucontrol # pulseaudio volume controle (GUI)
    vlc

    ## C / C++
    gcc
    gdb
    gnumake

    # Python
    python3
    python312Packages.ipython

    ## Misc
    winetricks
    wineWowPackages.wayland
    inputs.alejandra.defaultPackage.${system}
  ];
}
