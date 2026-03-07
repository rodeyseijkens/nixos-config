{
  pkgs,
  inputs,
  username,
  host,
  self,
  stateVersion,
  ...
}: {
  imports = [inputs.home-manager.nixosModules.home-manager];
  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs username host self stateVersion;};
    users.${username} = {
      imports = [
        ./../home
        ./../../hosts/${host}/home-configuration.nix
      ];
      home.username = "${username}";
      home.homeDirectory = "/home/${username}";
      home.stateVersion = stateVersion;
      programs.home-manager.enable = true;
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.zsh;
  };

  nix = {
    settings = {
      allowed-users = ["${username}"];
    };
  };
}
