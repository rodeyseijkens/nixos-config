{
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.zen-browser;
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
        search = {
          force = true;
          default = "ddg";
          engines = {
            "T3 Chat" = {
              name = "T3 Chat";
              urls = [
                {
                  template = "https://www.t3.chat/new";
                  params = [
                    {
                      name = "model";
                      value = "gemini-2.5-flash";
                    }
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              iconUpdateURL = "https://www.t3.chat/favicon.ico";
              definedAliases = ["@t3"];
            };

            "YouTube" = {
              name = "YouTube";
              urls = [
                {
                  template = "https://www.youtube.com/results";
                  params = [
                    {
                      name = "search_query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              iconUpdateURL = "https://www.youtube.com/favicon.ico";
              definedAliases = ["@yt"];
            };

            "GitHub" = {
              name = "GitHub";
              urls = [
                {
                  template = "https://github.com/search";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              iconUpdateURL = "https://github.com/favicon.ico";
              definedAliases = ["@gh"];
            };

            "Reddit" = {
              name = "Reddit";
              urls = [
                {
                  template = "https://www.reddit.com/search";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              iconUpdateURL = "https://www.reddit.com/favicon.ico";
              definedAliases = ["@r"];
            };

            "DuckDuckGo Maps" = {
              name = "DuckDuckGo Maps";
              urls = [
                {
                  template = "https://duckduckgo.com/";
                  params = [
                    {
                      name = "iaxm";
                      value = "maps";
                    }
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              iconUpdateURL = "https://duckduckgo.com/favicon.ico";
              definedAliases = ["@dmap"];
            };

            "Google Maps" = {
              name = "Google Maps";
              urls = [
                {
                  template = "https://www.google.com/maps";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              iconUpdateURL = "https://www.google.com/favicon.ico";
              definedAliases = ["@gmap"];
            };

            "Home Manager Options" = {
              name = "Home Manager Options";
              urls = [
                {
                  template = "https://home-manager-options.extranix.com/";
                  params = [
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                    {
                      name = "release";
                      value = "master";
                    }
                  ];
                }
              ];
              iconUpdateURL = "https://home-manager-options.extranix.com/favicon.ico";
              definedAliases = ["@nhm"];
            };

            "NixOS Packages" = {
              name = "NixOS Packages";
              urls = [
                {
                  template = "https://search.nixos.org/packages";
                  params = [
                    {
                      name = "channel";
                      value = "unstable";
                    }
                    {
                      name = "from";
                      value = "0";
                    }
                    {
                      name = "size";
                      value = "50";
                    }
                    {
                      name = "sort";
                      value = "relevance";
                    }
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              iconUpdateURL = "https://nixos.org/favicon.png";
              definedAliases = ["@nix"];
            };

            # Hide unwanted default engines
            "Bing".metaData.hidden = true;
            "Amazon.com".metaData.hidden = true;
            "eBay".metaData.hidden = true;
            "Wikipedia (en)".metaData.hidden = true;
            "Qwant".metaData.hidden = true;
            "Ecosia".metaData.hidden = true;
          };
        };
      };
    };
  };
}
