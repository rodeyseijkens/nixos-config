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
    ffmpeg # multimedia framework
    file # Show file information
    jq # command-line JSON processor
    killall # For Killing All Instances Of Programs
    lazygit # terminal git UI
    libnotify # Notification library
    man-pages # extra man pages
    mpv # video player
    ncdu # disk space
    nitch # systhem fetch util
    nix-prefetch-github
    openssl # cryptographic library
    pamixer # pulseaudio command line mixer
    playerctl # controller for media players
    unzip # unzip utility
    wget # file downloader
    wl-clipboard # clipboard utils for wayland (wl-copy, wl-paste)
    xdg-utils # utilities for desktop integration
    yazi # terminal file manager
    yt-dlp-light # audio/video downloader
    onefetch # git repository information tool
    gifsicle # gif utility - for record.sh
    zenity # simple dialog creator - for record.sh
    satty # snapshot editing tool - for screenshot.sh
    imagemagick # image manipulation tool
    viu # image viewer for terminal

    ## CLI fun
    cbonsai # terminal screensaver
    cmatrix # terminal screensaver
    pipes # terminal screensaver
    sl # steam locomotive
    tty-clock # cli clock

    ## GUI Apps
    bleachbit # cache cleaner
    libresprite # pixel art / sprite editor
    pwvucontrol # pipewire volume controle (GUI)
    mission-center # system monitor

    # Node.js
    volta

    ## Python
    python3
    python313Packages.ipython

    ## Misc
    winetricks
    wineWowPackages.wayland
    inputs.alejandra.defaultPackage.${pkgs.stdenv.hostPlatform.system} # syntax highlighter for nix
    proton-pass-cli
  ];
}
