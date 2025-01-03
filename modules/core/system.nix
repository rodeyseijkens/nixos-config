{
  self,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  # imports = [ inputs.nix-gaming.nixosModules.default ];
  nix = {
    settings = {
      allowed-users = ["${username}"];
      experimental-features = ["nix-command" "flakes"];
    };
  };
  nixpkgs = {
    overlays = [
      inputs.nur.overlays.default
      # TEMP: Electron build error workarounds
      (self: super: {
        electron_31 = self.electron;
      })
    ];
  };

  environment.systemPackages = with pkgs; [
    wget
    git
  ];

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "24.05";
}
