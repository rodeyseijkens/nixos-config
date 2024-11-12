{ pkgs, config, inputs, ... }: 
{
  home.packages = with pkgs;[
    ## Utils
    gamemode
    gamescope
    #winetricks
    #inputs.nix-gaming.packages.${pkgs.system}.wine-ge

    ## Minecraft
    # prismlauncher

    ## Cli games
    _2048-in-terminal
    vitetris
    nethack

    ## Emulation
    # sameboy
    # snes9x
    # cemu
    # dolphin-emu
  ];
}
