{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    ## LLM Tools
    python313Packages.llm # Command line tool for working with Large Language Models
    python313Packages.llm-openrouter # OpenRouter plugin for llm
  ];
}
