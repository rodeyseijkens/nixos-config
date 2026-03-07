#!/usr/bin/env sh
set -eu

staged_files="$(git diff --cached --name-only --diff-filter=ACMR | grep '^secrets/.*\.yaml$' || true)"

[ -n "$staged_files" ] || exit 0

for file in $staged_files; do
  [ -f "$file" ] || continue

  if ! grep -q '^sops:' "$file" || ! grep -q 'ENC\[' "$file"; then
    echo "Error: $file does not look like a sops-encrypted YAML file." >&2
    echo "Encrypt it with: sops $file" >&2
    exit 1
  fi
done
