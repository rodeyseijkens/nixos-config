{
  search = {
    force = true;
    default = "ddg";
    engines = {
      "t3-chat" = {
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
        icon = "https://www.t3.chat/favicon.ico";
        definedAliases = ["@t3"];
      };

      "youtube" = {
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
        icon = "https://www.youtube.com/favicon.ico";
        definedAliases = ["@yt"];
      };

      "github" = {
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
        icon = "https://github.com/favicon.ico";
        definedAliases = ["@gh"];
      };

      "reddit" = {
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
        icon = "https://www.reddit.com/favicon.ico";
        definedAliases = ["@r"];
      };

      "ddg-maps" = {
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
        icon = "https://duckduckgo.com/favicon.ico";
        definedAliases = ["@dmap"];
      };

      "g-maps" = {
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
        icon = "https://www.google.com/favicon.ico";
        definedAliases = ["@gmap"];
      };

      "nhm-options" = {
        name = "Home Manager NixOS Options";
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
        icon = "https://home-manager-options.extranix.com/favicon.ico";
        definedAliases = ["@nhm"];
      };

      "nixos-packages" = {
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
        icon = "https://nixos.org/favicon.png";
        definedAliases = ["@nix"];
      };

      # Hide unwanted default engines
      bing.metaData.hidden = true;
      amazondotcom-us.metaData.hidden = true;
      ebay.metaData.hidden = true;
      wikipedia.metaData.hidden = true;
      qwant.metaData.hidden = true;
      ecosia.metaData.hidden = true;
    };
  };
}
