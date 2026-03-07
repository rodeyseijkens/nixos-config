{
  inputs,
  pkgs,
  ...
}: let
  defaultModel = "openrouter/openrouter/free";
in {
  home.packages = with pkgs; [
    ## LLM Tools
    (llm.withPlugins {
      # LLM plugin for models hosted by OpenRouter
      llm-openrouter = true;
    })
  ];

  xdg.configFile."io.datasette.llm/default_model.txt".text = "${defaultModel}\n";
}
