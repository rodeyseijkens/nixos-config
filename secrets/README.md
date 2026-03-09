# Secrets (Simple Guide)

This folder stores encrypted secrets for sops-nix.

## Quick Start (new host)

1. **Print this host recipient**

```bash
secrets-helper host-key
```

2. **Add that recipient to `.sops.yaml`**

Add the printed `age1...` key to the correct host entry/rule.

3. **Create or update shared secrets**

```bash
secrets-helper git-init <github-username>
secrets-helper edit secrets/secrets.yaml
```

4. **Re-encrypt so this host can decrypt**

```bash
secrets-helper add-host secrets/secrets.yaml
```

`add-host` prompts for your admin `AGE-SECRET-KEY` (hidden input) and uses it only for that command.

5. **Apply and verify**

```bash
sudo nixos-rebuild test --flake .#<host>
ls -l /run/secrets
```

Expected: `/run/secrets/git-credentials` exists.

## Host-only Secrets (optional)

```bash
mkdir -p secrets/hosts
secrets-helper edit secrets/hosts/<host>.yaml
secrets-helper add-host secrets/hosts/<host>.yaml
```

## Daily Commands

```bash
secrets-helper edit secrets/secrets.yaml
secrets-helper add-host secrets/secrets.yaml
secrets-helper updatekeys-file secrets/secrets.yaml
secrets-helper updatekeys
```

## Troubleshooting

- Error: `0 successful groups required, got 0`
  - Cause: file was not re-encrypted for this host recipient.
  - Fix: add host recipient to `.sops.yaml`, then run `secrets-helper add-host secrets/secrets.yaml`.

- `add-host` asks for admin key
  - Use your private `AGE-SECRET-KEY-...` from your password manager.
  - Admin key is only needed on machines that edit/rekey secrets.

## Safety Rules

- Commit only encrypted `secrets/*.yaml` files.
- Do not keep plaintext backups in this repo.
