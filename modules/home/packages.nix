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
    imv # image viewer
    killall
    lazygit
    libnotify # Notification library
    man-pages # extra man pages
    mpv # video player
    ncdu # disk space
    nitch # systhem fetch util
    nix-prefetch-github
    openssl
    pamixer # pulseaudio command line mixer
    playerctl # controller for media players
    unzip
    wget
    wl-clipboard # clipboard utils for wayland (wl-copy, wl-paste)
    xdg-utils
    yazi # terminal file manager
    yt-dlp-light # audio/video downloader
    onefetch
    gifsicle # gif utility - for record.sh
    zenity # simple dialog creator - for record.sh
    swappy # snapshot editing tool - for screenshot.sh

    ## CLI fun
    cbonsai # terminal screensaver
    cmatrix
    pipes # terminal screensaver
    sl
    tty-clock # cli clock

    ## GUI Apps
    bleachbit # cache cleaner
    pwvucontrol # pipewire volume controle (GUI)
    vlc
    mission-center

    # Python
    python3
    python312Packages.ipython

    # Node.js
    volta

    ## Misc
    winetricks
    wineWowPackages.wayland
    inputs.alejandra.defaultPackage.${system}
  ];
}
