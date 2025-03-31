{
  description = "Rodey's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";

    hypr-contrib.url = "github:hyprwm/contrib";
    hyprpicker.url = "github:hyprwm/hyprpicker";

    alejandra.url = "github:kamadorueda/alejandra/3.0.0";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen = {
      url = "github:LovingMelody/nix-citizen";
      inputs.nix-gaming.follows = "nix-gaming";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:gerg-l/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprmag.url = "github:SIMULATAN/hyprmag";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-gnome-theme = {
      url = "github:rafaelmardojai/firefox-gnome-theme";
      flake = false;
    };
  };

  # All outputs for the system (configs)
  outputs = {
    nixpkgs,
    self,
    ...
  } @ inputs: let
    username = "rodey";
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    lib = nixpkgs.lib;

    # This lets us reuse the code to "create" a system
    # Credits go to sioodmy on this one!
    # https://github.com/sioodmy/dotfiles/blob/main/flake.nix
    mkSystem = pkgs: system: host:
      pkgs.lib.nixosSystem {
        system = system;
        modules = [
          # Hardware config (bootloader, kernel modules, filesystems, etc)
          # DO NOT USE MY HARDWARE CONFIG!! USE YOUR OWN!!
          ./hosts/${host}/hardware-configuration.nix
          # General configuration (networking, sound, etc)
          ./modules/core
          # Host specific configuration and overrides
          ./hosts/${host}/configuration.nix
        ];
        specialArgs = {inherit inputs username host self;};
      };
  in {
    nixosConfigurations = {
      # Now, defining a new system is can be done in one line
      #                                Architecture   Hostname
      desktop = mkSystem inputs.nixpkgs "x86_64-linux" "desktop";
      desktop-work = mkSystem inputs.nixpkgs "x86_64-linux" "desktop-work";
      laptop = mkSystem inputs.nixpkgs "x86_64-linux" "laptop";
      vm = mkSystem inputs.nixpkgs "x86_64-linux" "vm";
    };
  };
}
