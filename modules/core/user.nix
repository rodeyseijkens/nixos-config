{
  pkgs,
  inputs,
  username,
  host,
  self,
  ...
}: {
  imports = [inputs.home-manager.nixosModules.home-manager];
  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs username host self;};
    users.${username} = {
      imports = [
        ./../home
        ./../../hosts/${host}/home-configuration.nix
      ];
      home.username = "${username}";
      home.homeDirectory = "/home/${username}";
      home.stateVersion = "24.05";
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
