{
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.zen-browser;
  searchConfig = import ./profiles/search.nix;
in {
  options.modules.zen-browser = {enable = mkEnableOption "zen-browser";};
  imports = [inputs.zen-browser.homeModules.beta];
  config = mkIf cfg.enable {
    programs.zen-browser = {
      enable = true;
      policies = {
        DisableAppUpdate = true;
        DisableTelemetry = true;
        # find more options here: https://mozilla.github.io/policy-templates/
      };
      profiles.default = {
        name = "Default";
        search = searchConfig.search;
      };
    };
  };
}
