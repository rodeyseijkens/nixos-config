#!/usr/bin/env bash

# Remove old volta folder
rm -rf "$HOME/.volta"

# Install packages
volta install node@latest
volta install @antfu/ni@latest
volta install pnpm@latest
volta install @biomejs/biome
volta install opencode-ai@latest