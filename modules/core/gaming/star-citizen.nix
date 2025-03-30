{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    # or home.packages
    inputs.nix-gaming.packages.${pkgs.system}.star-citizen # installs a package
  ];
  boot.kernel.sysctl = {
    "fs.file-max" = 524288;
  };
}
