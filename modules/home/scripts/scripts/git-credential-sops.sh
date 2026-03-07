#!/usr/bin/env sh
set -eu

store_file="/run/secrets/git-credentials"
action="${1:-}"

case "$action" in
  get)
    if [ -r "$store_file" ]; then
      git credential-store --file "$store_file" get
    fi
    ;;
  store|erase)
    # Read-only helper: secrets are managed by sops-nix, not written by git.
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
