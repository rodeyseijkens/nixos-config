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
# The ESP script rides in the system closure through the aarambh-uninstall
# wrapper (the only system package exposing it). Build the cached toplevel and
# resolve the wrapper's exec path.
TL=$(nix build --no-link --print-out-paths '.#nixosConfigurations.desktop.config.system.build.toplevel' | tail -n1)
wrapper=$(readlink -f "$TL/sw/bin/aarambh-uninstall")
SCRIPT=$(sed -n 's/^exec \(.*\/bin\/aarambh-esp\).*/\1/p' "$wrapper" | head -n1)
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

# The firmware entry matcher, against the efibootmgr -v shape this firmware
# prints (no File() label on the path node). A stub efibootmgr feeds the
# captured real output.
cat >"$ESP/efibootmgr-sample.txt" <<'EOF'
BootCurrent: 0003
Timeout: 1 seconds
BootOrder: 0006,0003,0005,0000,0008,0001,0002,0004
Boot0000* Windows Boot Manager  HD(1,GPT,4a512320-ad94-44b6-883f-ba9c8a3335c2,0x1000,0xf8fff)/\EFI\MICROSOFT\BOOT\BOOTMGFW.EFI57494e444f5753000100000088000000780000004200430044004f0042004a004500430054003d007b00390064006500610038003600320063002d0035006300640064002d0034006500370030002d0061006300630031002d006600330032006200330034003400640034003700390035007d00000033000100000010000000040000007fff0400
Boot0001* UEFI:CD/DVD Drive     BBS(129,,0x0)
Boot0002* UEFI:Removable Device BBS(130,,0x0)
Boot0003* Linux Boot Manager    HD(1,GPT,b85a008a-8f4f-45d8-a72e-26b9794d9cd4,0x1000,0x100000)/\EFI\SYSTEMD\SYSTEMD-BOOTX64.EFI
Boot0004* UEFI:Network Device   BBS(131,,0x0)
Boot0005* Linux Boot Manager    HD(1,GPT,4a512320-ad94-44b6-883f-ba9c8a3335c2,0x1000,0xf8fff)/\EFI\SYSTEMD\SYSTEMD-BOOTX64.EFI
Boot0006* Aarambh       HD(1,GPT,b85a008a-8f4f-45d8-a72e-26b9794d9cd4,0x1000,0x100000)/\EFI\aarambh\aarambh.efi
Boot0008* UEFI OS       HD(1,GPT,b85a008a-8f4f-45d8-a72e-26b9794d9cd4,0x1000,0x100000)/\EFI\BOOT\BOOTX64.EFI0000424f
EOF

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

# A fake efibootmgr that prints the sample; put it first on PATH.
mkdir -p "$WORK/bin"
cat >"$WORK/bin/efibootmgr" <<EOF
#!$(command -v bash)
cat "$ESP/efibootmgr-sample.txt"
EOF
chmod +x "$WORK/bin/efibootmgr"

{
    sed -n '/^find_boot_entry()/,/^}/p' "$SCRIPT"
} >"$WORK/match.sh"

match() {
    PATH="$WORK/bin:$PATH" bash -c 'set -eo pipefail; source "$0"; find_boot_entry "$1" "$2"' \
        "$WORK/match.sh" "$1" "$2"
}

check "aarambh entry found" "0006" "$(match "b85a008a-8f4f-45d8-a72e-26b9794d9cd4" '\EFI\aarambh\aarambh.efi')"
check "systemd-boot entry found" "0003" "$(match "b85a008a-8f4f-45d8-a72e-26b9794d9cd4" '\EFI\systemd\systemd-bootx64.efi')"
check "windows entry found" "0000" "$(match "4a512320-ad94-44b6-883f-ba9c8a3335c2" '\EFI\MICROSOFT\BOOT\BOOTMGFW.EFI')"
check "work systemd-boot entry found" "0005" "$(match "4a512320-ad94-44b6-883f-ba9c8a3335c2" '\EFI\systemd\systemd-bootx64.efi')"
check "other volume not matched" "" "$(match "4a512320-ad94-44b6-883f-ba9c8a3335c2" '\EFI\aarambh\aarambh.efi')"

if [ "$fail" = 0 ]; then
    echo "PASS: firmware entry matcher"
else
    echo "FAILED"
    exit 1
fi
