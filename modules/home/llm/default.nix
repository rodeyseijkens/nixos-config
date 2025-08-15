{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    ## LLM Tools
    (python313Packages.llm.withPlugins {
      # LLM plugin for models hosted by OpenRouter
      llm-openrouter = true;
    })
  ];
}
