#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
secrets-helper

Usage:
  secrets-helper admin-key
      Create ~/.config/sops/age/keys.txt if missing and print admin age recipient

  secrets-helper edit <path>
      Open a secrets file with sops (creates it if it does not exist)

  secrets-helper git-init [username] [token]
      Create/update secrets/secrets.yaml with git-credentials and encrypt it
      - token optional: uses gh auth token when available, else placeholder

  secrets-helper host-key
      Print this machine's age recipient derived from /etc/ssh/ssh_host_ed25519_key.pub

  secrets-helper updatekeys
      Re-encrypt all encrypted YAML files under <repo>/secrets using .sops.yaml

  secrets-helper updatekeys-file <path>
      Re-encrypt a single file (for example: secrets/secrets.yaml)
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' is required but not found in PATH." >&2
    exit 1
  fi
}

run_sops() {
  if command -v sops >/dev/null 2>&1; then
    sops "$@"
  else
    nix shell nixpkgs#sops -c sops "$@"
  fi
}

run_age_keygen() {
  if command -v age-keygen >/dev/null 2>&1; then
    age-keygen "$@"
  else
    nix shell nixpkgs#age -c age-keygen "$@"
  fi
}

find_repo_root() {
  if command -v git >/dev/null 2>&1; then
    root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$root" ] && [ -f "$root/.sops.yaml" ] && [ -d "$root/secrets" ]; then
      printf "%s\n" "$root"
      return 0
    fi
  fi

  if [ -f .sops.yaml ] && [ -d secrets ]; then
    pwd
    return 0
  fi

  return 1
}

cmd_admin_key() {
  age_dir="${HOME}/.config/sops/age"
  key_file="${age_dir}/keys.txt"

  mkdir -p "$age_dir"
  chmod 700 "$age_dir"

  if [ ! -f "$key_file" ]; then
    run_age_keygen -o "$key_file" >/dev/null
  fi

  chmod 600 "$key_file"

  pub="$(grep '^# public key:' "$key_file" | sed 's/^# public key: //')"
  if [ -z "$pub" ]; then
    echo "Error: could not read public key from $key_file" >&2
    exit 1
  fi

  printf "%s\n" "$pub"
}

cmd_host_key() {
  if [ ! -f /etc/ssh/ssh_host_ed25519_key.pub ]; then
    echo "Error: /etc/ssh/ssh_host_ed25519_key.pub not found." >&2
    echo "Run this on a NixOS host with OpenSSH host keys present." >&2
    exit 1
  fi

  if command -v ssh-to-age >/dev/null 2>&1; then
    cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
  else
    nix shell nixpkgs#ssh-to-age -c sh -c 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
  fi
}

cmd_updatekeys() {
  root="$(find_repo_root || true)"
  if [ -z "$root" ]; then
    echo "Error: could not find repo root (expected .sops.yaml and ./secrets)." >&2
    echo "Run this command from inside your nixos-config repository." >&2
    exit 1
  fi

  files=$(find "$root/secrets" -type f -name '*.yaml' | sort)

  if [ -z "$files" ]; then
    echo "No encrypted YAML files found under $root/secrets"
    exit 0
  fi

  echo "$files" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    echo "Updating recipients: $f"
    run_sops updatekeys -y "$f"
  done
}

cmd_updatekeys_file() {
  if [ $# -ne 1 ]; then
    echo "Error: updatekeys-file requires exactly one path argument." >&2
    usage
    exit 1
  fi

  file="$1"
  if [ ! -f "$file" ]; then
    echo "Error: file not found: $file" >&2
    exit 1
  fi

  echo "Updating recipients: $file"
  run_sops updatekeys -y "$file"
}

cmd_edit() {
  if [ $# -ne 1 ]; then
    echo "Error: edit requires exactly one path argument." >&2
    usage
    exit 1
  fi

  file="$1"

  dir="$(dirname "$file")"
  mkdir -p "$dir"

  run_sops "$file"
}

cmd_git_init() {
  if [ "$#" -gt 2 ]; then
    echo "Error: git-init accepts up to two arguments: [username] [token]" >&2
    usage
    exit 1
  fi

  username="${1:-username}"
  token="${2:-}"

  if [ -z "$token" ] && command -v gh >/dev/null 2>&1; then
    token="$(gh auth token 2>/dev/null || true)"
  fi

  root="$(find_repo_root || true)"
  if [ -z "$root" ]; then
    echo "Error: could not find repo root (expected .sops.yaml and ./secrets)." >&2
    echo "Run this command from inside your nixos-config repository." >&2
    exit 1
  fi

  file="$root/secrets/secrets.yaml"
  mkdir -p "$root/secrets"

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT INT TERM

  if [ -f "$file" ]; then
    run_sops -d "$file" > "$tmp"
  fi

  if grep -q '^git-credentials:[[:space:]]*|' "$tmp" 2>/dev/null; then
    cleaned="$(mktemp)"
    awk '
      BEGIN { skip = 0 }
      /^git-credentials:[[:space:]]*\|[[:space:]]*$/ { skip = 1; next }
      {
        if (skip == 1) {
          if ($0 ~ /^[^[:space:]].*:[[:space:]]*/) {
            skip = 0
            print
          }
          next
        }
        print
      }
    ' "$tmp" > "$cleaned"
    mv "$cleaned" "$tmp"
  fi

  if [ -s "$tmp" ]; then
    printf "\n" >> "$tmp"
  fi

  if [ -n "$token" ]; then
    printf "git-credentials: |\n  https://%s:%s@github.com\n" "$username" "$token" >> "$tmp"
  else
    printf "git-credentials: |\n  https://%s:YOUR_GITHUB_TOKEN@github.com\n" "$username" >> "$tmp"
  fi

  cp "$tmp" "$file"
  run_sops --encrypt --in-place "$file"

  if [ -n "$token" ]; then
    echo "Initialized git-credentials in $file (token sourced from gh/argument)"
  else
    echo "Initialized git-credentials in $file (placeholder token; update it with secrets-helper edit)"
  fi
}

cmd="${1:-}"

case "$cmd" in
  admin-key)
    cmd_admin_key
    ;;
  host-key)
    cmd_host_key
    ;;
  updatekeys)
    cmd_updatekeys
    ;;
  updatekeys-file)
    shift
    cmd_updatekeys_file "$@"
    ;;
  edit)
    shift
    cmd_edit "$@"
    ;;
  git-init)
    shift
    cmd_git_init "$@"
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "Error: unknown command '$cmd'" >&2
    usage
    exit 1
    ;;
esac
