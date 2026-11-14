#!/usr/bin/env bash
# Checks the kernel-list writer and the firmware entry matcher inside the built
# aarambh-esp script, against synthetic data shaped like the real thing: BLS
# entries as the NixOS boot builder writes them, and efibootmgr -v output as
# this firmware prints it. Touches nothing outside the sandbox.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ESP=$(mktemp -d)
WORK=$ESP/work
trap 'rm -rf "$ESP"' EXIT
mkdir -p "$WORK/loader/entries" "$WORK/bin"

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

# The built script comes from the flake's cached toplevel.
set -e
TL=$(nix build --no-link --print-out-paths '.#nixosConfigurations.desktop.config.system.build.toplevel' | tail -n1)
wrapper=$(readlink -f "$TL/sw/bin/aarambh-uninstall")
SCRIPT=$(sed -n 's/^exec \(.*\/bin\/aarambh-esp\).*/\1/p' "$wrapper" | head -n1)
set -uo pipefail

if [ -z "$SCRIPT" ] || [ ! -x "$SCRIPT" ]; then
    echo "FAIL: the built aarambh-esp is missing (wrapper: $wrapper)"
    exit 1
fi

# Entries as the NixOS boot builder writes them: the title is always "NixOS",
# the version line carries the generation number and the build date it baked
# in, and the file names are content hashes.
write_entry() {
    local file=$1
    cat >"$WORK/loader/entries/$file"
}

write_entry nixos-1a2b3c4d+0.conf <<'EOF'
title NixOS
version Generation 900 NixOS 26.11.20261114.2074cc6, built on 2026-11-12
linux /EFI/nixos/38d7zfrn8p7d-scheme-bzImage.efi
initrd /EFI/nixos/38d7zfrn8p7d-scheme-initrd-Linux-7.3-zen.efi
initrd /EFI/nixos/38d7zfrn8p7d-plymouth-initrd.efi
options logLevel=7 root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654
machine-id 0e3f5167ca9f43b1a7d19c47e2b8a6f0
sort-key nixos
EOF

write_entry nixos-5e6f7a8b+0.conf <<'EOF'
title NixOS
version Generation 899 NixOS 26.11.20261112.83c50f3f, built on 2026-11-08
linux /EFI/nixos/annex2x9mzzc-scheme-bzImage.efi
initrd /EFI/nixos/annex2x9mzzc-scheme-initrd-Linux-7.3-zen.efi
options root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654
machine-id 0e3f5167ca9f43b1a7d19c47e2b8a6f0
sort-key nixos
EOF

# An older generation and one without a Generation-prefixed version line.
write_entry nixos-9c0d1e2f+0.conf <<'EOF'
title NixOS
version Generation 45 NixOS 26.05.20260801.1f2a9c11, built on 2026-08-01
linux /EFI/nixos/o93m6f4h0ff-scheme-bzImage.efi
initrd /EFI/nixos/o93m6f4h0ff-scheme-initrd-Linux-7.1-zen.efi
options root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654
machine-id 0e3f5167ca9f43b1a7d19c47e2b8a6f0
sort-key nixos
EOF

write_entry o_memtest86.conf <<'EOF'
title Memtest86+
version 7.1
linux /EFI/memtest86/memtest.efi
EOF

# An entry without a linux line: never listed.
write_entry broken.conf <<'EOF'
title Broken
options nothing
EOF

# Stubs with the outputs of the real tools. The generation dates differ from
# the baked-in version dates on purpose: the writer must use the profile list.
cat >"$WORK/bin/nix-env" <<'EOF'
#!/usr/bin/env bash
cat "$AARAMBH_NIX_ENV_SAMPLE"
EOF
cat >"$WORK/bin/efibootmgr" <<'EOF'
#!/usr/bin/env bash
cat "$AARAMBH_EFIBOOTMGR_SAMPLE"
EOF
chmod +x "$WORK/bin/nix-env" "$WORK/bin/efibootmgr"

cat >"$WORK/nix-env-sample.txt" <<'EOF'
  900   2026-11-14 19:55:42: (empty): change version to 26.11.20261114.2074cc6
  899   2026-11-10 18:02:11: (empty): change version to 26.11.20261112.83c50f3f
   45   2026-08-01 09:00:00: (empty): change version to 26.05.20260801.1f2a9c11
EOF

cat >"$WORK/efibootmgr-sample.txt" <<'EOF'
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

# Extract the functions (and their helpers) from the built script.
{
    sed -n '/^bls_field()/,/^}/p;/^bls_all()/,/^}/p;/^uefi_path()/,/^}/p;/^write_kernels()/,/^}/p' "$SCRIPT"
} >"$WORK/kernels.sh"
{
    sed -n '/^find_boot_entry()/,/^}/p' "$SCRIPT"
} >"$WORK/match.sh"

# Run one of the extracted functions with the stubs on PATH and ESP pointed at
# the fake tree (the script's own ESP default only applies when it runs whole).
run_fn() {
    ESP="$WORK" \
    PATH="$WORK/bin:$PATH" \
    AARAMBH_NIX_ENV_SAMPLE="$WORK/nix-env-sample.txt" \
    AARAMBH_EFIBOOTMGR_SAMPLE="$WORK/efibootmgr-sample.txt" \
        bash -c 'set -eo pipefail; source "$0"; "$@"' "$1" "${@:2}"
}

run_fn "$WORK/kernels.sh" write_kernels >"$WORK/nixos.kernels"

echo "=== DEBUG kernels.sh (first 10):"
head -10 "$WORK/kernels.sh" 1>&2
echo "=== DEBUG nixos.kernels:" 1>&2
cat "$WORK/nixos.kernels" 1>&2

# Kernel list checks.
expected_900="NixOS (generation 900, built on 2026-11-14)|nixos-1a2b3c4d+0|\EFI\nixos\38d7zfrn8p7d-scheme-bzImage.efi|\EFI\nixos\38d7zfrn8p7d-scheme-initrd-Linux-7.3-zen.efi,\EFI\nixos\38d7zfrn8p7d-plymouth-initrd.efi|logLevel=7 root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654"
expected_899="NixOS (generation 899, built on 2026-11-10)|nixos-5e6f7a8b+0|\EFI\nixos\annex2x9mzzc-scheme-bzImage.efi|\EFI\nixos\annex2x9mzzc-scheme-initrd-Linux-7.3-zen.efi|root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654"

check "line count" 5 "$(wc -l <"$WORK/nixos.kernels" | tr -d ' ')"
check "oneshot header" "@oneshot systemd-boot" "$(head -n1 "$WORK/nixos.kernels")"
check "generation 900 line" "$expected_900" "$(sed -n 2p "$WORK/nixos.kernels")"
check "generation 899 line" "$expected_899" "$(sed -n 3p "$WORK/nixos.kernels")"
check "generation 45 line" "NixOS (generation 45, built on 2026-08-01)|nixos-9c0d1e2f+0|\EFI\nixos\o93m6f4h0ff-scheme-bzImage.efi|\EFI\nixos\o93m6f4h0ff-scheme-initrd-Linux-7.1-zen.efi|root=UUID=5d1d8a71-5e1a-4957-9326-340c7d8ad654" \
    "$(sed -n 4p "$WORK/nixos.kernels")"
check "memtest last, plain title" "Memtest86+" "$(sed -n 5p "$WORK/nixos.kernels" | cut -d'|' -f1)"
check "the no-linux entry skipped" 0 "$(grep -c "Broken" "$WORK/nixos.kernels" || true)"

if [ "$fail" = 0 ]; then
    echo "PASS: kernel list writer"
else
    echo "FAILED"
    exit 1
fi

# Firmware entry matcher checks.
fail=0

match() {
    run_fn "$WORK/match.sh" find_boot_entry "$1" "$2"
}

check "aarambh entry found" "0006" "$(match "b85a008a-8f4f-45d8-a72e-26b9794d9cd4" '\EFI\aarambh\aarambh.efi')"
check "systemd-boot entry found" "0003" "$(match "b85a008a-8f4f-45d8-a72e-26b9794d9cd4" '\EFI\systemd\systemd-bootx64.efi')"
check "windows entry found" "0000" "$(match "4a512320-ad94-44b6-883f-ba9c8a3335c2" '\EFI\MICROSOFT\BOOT\BOOTMGFW.EFI')"
check "work systemd-boot entry found" "0005" "$(match "4a512320-ad94-44b6-883f-ba9c8a3335c2" '\EFI\systemd\systemd-bootx64.EFI')"
check "other volume not matched" "" "$(match "4a512320-ad94-44b6-883f-ba9c8a3335c2" '\EFI\aarambh\aarambh.efi')"

if [ "$fail" = 0 ]; then
    echo "PASS: firmware entry matcher"
else
    echo "FAILED"
    exit 1
fi
