{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    inputs.nix-citizen.packages.${pkgs.system}.star-citizen
  ];
  boot.kernel.sysctl = {
    "fs.file-max" = 524288;
  };
}
