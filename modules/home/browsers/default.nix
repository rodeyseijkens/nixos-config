{
  lib,
  ...
}: {
  imports = [
    ./google-chrome.nix
    ./zen-browser.nix
  ];

  options.modules.defaultBrowser = lib.mkOption {
    type = lib.types.enum ["zen-beta" "google-chrome"];
    default = "zen-beta";
    description = "Default browser for xdg defaults, BROWSER and the super+b binding";
  };
}
