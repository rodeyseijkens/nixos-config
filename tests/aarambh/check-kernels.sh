#!/usr/bin/env bash
# Checks the kernel-list writer inside the built aarambh-esp script against a
# synthetic set of BootLoaderSpec entries: the same files systemd-boot writes
# to /boot/loader/entries. Run inside the sandbox; touches nothing.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ESP=$(mktemp -d)
TMPDIR=$ESP/tmp
WORK=$ESP/work
trap 'rm -rf "$ESP"' EXIT
mkdir -p "$TMPDIR" "$WORK/loader/entries"
export TMPDIR

# The built script comes from a plain nix build.
set -e
# The ESP script's store path shows up in the aarambh-uninstall wrapper, which
# execs it by absolute path.
UNINSTALL=$(
    nix eval --json --impure --expr "
      let
        flake = builtins.getFlake \"path:$ROOT\";
        lib = flake.inputs.nixpkgs.lib;
        system = flake.nixosConfigurations.desktop.config;
        matches = builtins.filter (p: lib.hasSuffix \"aarambh-uninstall\" (baseNameOf p)) system.environment.systemPackages;
      in
        map (p: p) matches" |
        python3 -c 'import json,sys; v=[s for s in json.load(sys.stdin) if s]; print(v[0] if v else "")'
)
if [ -z "$UNINSTALL" ]; then
    echo "FAIL: aarambh-uninstall not found among the desktop's system packages"
    exit 1
fi
SCRIPT=$(sed -n "s/.*exec \(.*\/bin\/aarambh-esp\).*/\1/p" "$UNINSTALL/bin/aarambh-uninstall" | head -n1)
set -uo pipefail

if [ ! -x "$SCRIPT" ]; then
    echo "FAIL: the built aarambh-esp is missing: $SCRIPT"
    exit 1
fi

write_entry() {
    local file=$1
    cat >"$WORK/loader/entries/$file"
}

# Newest on top, as systemd-boot lays them out: one per generation. Two initrd
# lines and a windows-flavoured option line exercise the field handling.
write_entry nixos-generation-900.conf <<'EOF'
title NixOS 26.11 (generation 900)
linux /EFI/nixos/38d7zfrn8p7d-scheme-bzImage.efi
initrd /EFI/nixos/38d7zfrn8p7d-scheme-initrd-Linux-7.3-zen.efi
initrd /EFI/nixos/38d7zfrn8p7d-plymouth-initrd.efi
options logLevel=7 root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654
EOF

write_entry nixos-generation-899.conf <<'EOF'
title NixOS 26.11 (generation 899)
linux /EFI/nixos/annex2x9mzzc-scheme-bzImage.efi
initrd /EFI/nixos/annex2x9mzzc-scheme-initrd-Linux-7.3-zen.efi
options root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654
EOF

# Older entry first in name, with a date-stamped name that sorts before the
# ones above: the sort must be by version, newest first.
write_entry nixos-generation-45.conf <<'EOF'
title NixOS (old)
linux /EFI/nixos/o93m6f4h0ff-scheme-bzImage.efi
initrd /EFI/nixos/o93m6f4h0ff-scheme-initrd-Linux-7.1-zen.efi
options root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654
EOF

# An entry WITHOUT a linux line (a shared-OS left-over? a memory test): skipped.
write_entry firmware-test.conf <<'EOF'
title Firmware test
options noarg
EOF

# Extract the write_kernels function (and its helpers) from the built script.
# The built script keeps the placeholders replaced, so paths are real.
sed -n '/^bls_field()/,/^}/p;/^bls_all()/,/^}/p;/^uefi_path()/,/^}/p;/^write_kernels()/,/^}/p' \
    "$SCRIPT" >/dev/null || true
{
    sed -n '/^bls_field()/,/^}/p' "$SCRIPT"
    sed -n '/^bls_all()/,/^}/p' "$SCRIPT"
    sed -n '/^uefi_path()/,/^}/p' "$SCRIPT"
    sed -n '/^write_kernels()/,/^}/p' "$SCRIPT"
} >"$WORK/extract.sh"

ESP="$WORK" bash -c 'set -eo pipefail; source "$0"; write_kernels' "$WORK/extract.sh" >"$WORK/nixos.kernels"

fail=0
check() {
    if [ "$2" = "$3" ]; then
        echo "ok: $1"
    else
        echo "FAIL: $1"
        echo "  expected: $2"
        echo "  got:      $3"
        fail=1
    fi
}

check "line count" 4 "$(wc -l <"$WORK/nixos.kernels" | tr -d ' ')"
check "oneshot header" "@oneshot systemd-boot" "$(head -n1 "$WORK/nixos.kernels")"

# Generation 900: newest, two initrd paths folded to a comma list, options kept.
expected_900="NixOS 26.11 (generation 900)|nixos-generation-900|\EFI\nixos\38d7zfrn8p7d-scheme-bzImage.efi|\EFI\nixos\38d7zfrn8p7d-scheme-initrd-Linux-7.3-zen.efi,\EFI\nixos\38d7zfrn8p7d-plymouth-initrd.efi|logLevel=7 root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654"
check "generation 900 line" "$expected_900" "$(sed -n 2p "$WORK/nixos.kernels")"

check "generation 899 line" "NixOS 26.11 (generation 899)|nixos-generation-899|\EFI\nixos\annex2x9mzzc-scheme-bzImage.efi|\EFI\nixos\annex2x9mzzc-scheme-initrd-Linux-7.3-zen.efi|root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654" \
    "$(sed -n 3p "$WORK/nixos.kernels")"

check "old entry last" "NixOS (old)" "$(sed -n 4p "$WORK/nixos.kernels" | cut -d'|' -f1)"
check "the no-linux entry skipped" 0 "$(grep -c "Firmware test" "$WORK/nixos.kernels" || true)"

if [ "$fail" = 0 ]; then
    echo "PASS: kernel list writer"
else
    echo "FAILED"
    exit 1
fi
