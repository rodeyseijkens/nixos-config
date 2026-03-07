{
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.zen-browser;
  searchConfig = import ./profiles/search.nix;

  extension = shortId: guid: {
    name = guid;
    value = {
      install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
      installation_mode = "normal_installed";
    };
  };

  extensions = [
    (extension "facebook-container" "@contain-facebook")
    (extension "clearurls" "{74145f27-f039-47ce-a470-a662b129930a}")
    (extension "consent-o-matic" "gdpr@cavi.au.dk")
    (extension "multi-account-containers" "@testpilot-containers")
    (extension "duckduckgo-for-firefox" "jid1-ZAdIEUB7XOzOJw@jetpack")
    (extension "ublock-origin" "uBlock0@raymondhill.net")
    (extension "youtube-tweaks" "{d867162c-4c38-4c5f-aca4-db6a6592d7da}")
    (extension "proton-pass" "78272b6fa58f4a1abaac99321d503a20@proton.me")
  ];

  prefs = {
    "browser.newtabpage.activity-stream.feeds.section.highlights" = true;
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = true;
    "browser.newtabpage.activity-stream.system.showWeatherOptIn" = false;
    "browser.newtabpage.activity-stream.topSitesRows" = 2;
    "browser.search.region" = "NL";
    "browser.startup.homepage" = "https://duckduckgo.com/";
    "browser.startup.page" = 1;
    "browser.toolbars.bookmarks.visibility" = "always";
    "font.name.monospace.x-western" = "Maple Mono NF CN";
    "font.name.sans-serif.x-western" = "Maple Mono NF CN";
    "font.name.serif.x-western" = "Maple Mono NF CN";
    "privacy.donottrackheader.enabled" = true;
    "privacy.globalprivacycontrol.enabled" = false;
    "privacy.history.custom" = true;
    "privacy.trackingprotection.enabled" = true;
    "reader.color_scheme" = "custom";
    "reader.custom_colors.background" = "#1d2021";
    "reader.custom_colors.foreground" = "#d5c4a1";
    "reader.custom_colors.selection-highlight" = "#bdae93";
    "reader.custom_colors.unvisited-links" = "#98971a";
    "reader.custom_colors.visited-links" = "#d16286";
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    "zen.glance.enabled" = false;
    "zen.tabs.show-newtab-vertical" = false;
    "zen.tabs.vertical.right-side" = true;
    "zen.view.compact.enable-at-startup" = true;
    "zen.view.compact.should-enable-at-startup" = true;
    "zen.window-sync.enabled" = false;
    "zen.workspaces.separate-essentials" = false;
  };
in {
  options.modules.zen-browser = {enable = mkEnableOption "zen-browser";};
  imports = [inputs.zen-browser.homeModules.beta];
  config = mkIf cfg.enable {
    programs.zen-browser = {
      enable = true;
      policies = {
        DisableAppUpdate = true;
        DisableTelemetry = true;
        ExtensionSettings = listToAttrs extensions;
        # find more options here: https://mozilla.github.io/policy-templates/
      };
      profiles.default = {
        name = "Default";
        search = searchConfig.search;
        settings = prefs;
      };
    };
  };
}
