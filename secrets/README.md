# Secrets Management with sops-nix

This directory contains encrypted secrets managed by [sops-nix](https://github.com/Mic92/sops-nix).

## File Layout

- `secrets/secrets.yaml` → shared secrets
- `secrets/hosts/<host>.yaml` → host-only secrets (decryptable by that host only)

The recipient policy is defined in the repo-root `.sops.yaml`.

## Initial Setup

1. **Generate age recipients from each host SSH key**

```bash
nix shell nixpkgs#ssh-to-age -c sh -c 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
```

2. **Update `.sops.yaml` with real recipients**

Replace all `age1..._here` placeholders (including optional admin recovery key).

3. **Create encrypted secret files**

```bash
 # Shared secrets
sops secrets/secrets.yaml

 # Host-specific secrets (example for desktop-office)
mkdir -p secrets/hosts
sops secrets/hosts/desktop-office.yaml
```

4. **Add keys used by your Nix modules**

`modules/core/secrets.nix` currently expects this key in `secrets/secrets.yaml`:

```yaml
git-credentials: |
  https://username:REPLACE_ME@github.com
```

## Runtime Usage

Secrets are exposed at `/run/secrets/<name>` with mode `0400`.

Examples:

- `/run/secrets/git-credentials`

## Key Operations

- **Edit secrets:** `sops secrets/secrets.yaml`
- **Re-encrypt after recipient changes:** `sops updatekeys secrets/secrets.yaml`
- **Re-encrypt all secret files:**

  ```bash
  find secrets -type f -name '*.yaml' -exec sops updatekeys {} \;
  ```

## Helper Script

You can use the repo helper script:

```bash
secrets-helper admin-key
secrets-helper git-init [username] [token]
secrets-helper edit secrets/secrets.yaml
secrets-helper host-key
secrets-helper updatekeys
secrets-helper updatekeys-file secrets/secrets.yaml
```

`git-init` uses `gh auth token` automatically when available, unless you pass a token explicitly.

If `ssh-to-age` or `sops` are missing, run via a nix shell:

```bash
nix shell nixpkgs#sops nixpkgs#ssh-to-age -c secrets-helper host-key
```

## Verify

After creating/updating secrets:

```bash
sudo nixos-rebuild test --flake .#<host>
ls -l /run/secrets
```

## Security Notes

- Commit only encrypted `.yaml` files.
- Never keep plaintext backups (`*.dec`, `*.bak`) in this repo.
- Keep at least one recovery recipient (admin age key) in `.sops.yaml`.

## Secret Scanning

This repo uses `pre-commit` with:

- a local hook that rejects plaintext YAML under `secrets/`
- `gitleaks` to catch accidental secret material elsewhere

Install hooks once per clone:

```bash
pre-commit install
pre-commit run --all-files
```
