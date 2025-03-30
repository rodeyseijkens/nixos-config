{
  self,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      substituters = [
        "https://nix-gaming.cachix.org"
        "https://hyprland.cachix.org"
        "https://nix-citizen.cachix.org"
      ];
      trusted-public-keys = [
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="
      ];
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
    ntfs3g
  ];

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "24.05";
}
