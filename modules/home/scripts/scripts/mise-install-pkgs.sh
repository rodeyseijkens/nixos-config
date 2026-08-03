#!/usr/bin/env bash

# Core runtimes first
mise use -g node@latest
mise use -g pnpm@latest

# pnpm must be installed before the npm: tools below, since
# MISE_NPM_PACKAGE_MANAGER=pnpm shells out to pnpm for npm: installs.
mise install pnpm

# npm: tools (installed via pnpm)
mise use -g npm:@antfu/ni@latest
mise use -g npm:@biomejs/biome@latest
mise use -g npm:@kilocode/cli@latest

# Some npm packages (e.g. @biomejs/biome) ship native bindings that pnpm
# blocks by default. If install fails with a build-approval error, run:
#   pnpm approve-builds
# and approve the listed packages, then re-run this script.
