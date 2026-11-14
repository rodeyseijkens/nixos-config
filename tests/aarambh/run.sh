#!/usr/bin/env bash
#
# Boots Aarambh in QEMU from two test disks, checks cross-disk discovery and the
# editorial-gruvbox theme.
#
#   desktop.img  the desktop ESP: Aarambh (as the removable-media loader), its
#                menu config and its files
#   work.img     a second ESP with fake Windows Boot Manager and fake
#                systemd-boot loaders, the two loaders the menu points at
#
# Each fake loader writes a marker file to its own volume and shuts the VM down.
# A case passes when the marker lands on the work ESP, and the screen shows the
# theme colours. Explicit cases start an entry from the config. Autodetect cases
# use a config with no explicit OS entries, so the work ESP is found only by
# autodetect.
#
# Usage: tests/aarambh/run.sh
#
# Needs nix. QEMU, OVMF, gnu-efi, mtools, gptfdisk, dosfstools, ImageMagick and
# netcat come from nixpkgs through `nix shell`. Output goes to build/aarambh-qemu/.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$ROOT/tests/aarambh"
WORK="$ROOT/build/aarambh-qemu"

if [ -z "${AARAMBH_TEST_SHELL:-}" ]; then
    exec nix shell nixpkgs#qemu nixpkgs#OVMF nixpkgs#gnu-efi nixpkgs#gcc nixpkgs#binutils \
        nixpkgs#mtools nixpkgs#dosfstools nixpkgs#gptfdisk nixpkgs#imagemagick nixpkgs#netcat \
        --command env AARAMBH_TEST_SHELL=1 bash "$0" "$@"
fi

DESKTOP_PARTUUID="b85a008a-8f4f-45d8-a72e-26b9794d9cd4"
WORK_PARTUUID="4a512320-ad94-44b6-883f-ba9c8a3335c2"
OFFSET=1048576 # first partition starts at sector 2048, 512-byte sectors
export MTOOLS_SKIP_CHECK=1

FAILURES=0

fail() {
    echo "FAIL: $*"
    FAILURES=$((FAILURES + 1))
}

# Builds the menu package with the same palette the module uses.
build_package() {
    nix build --no-link --print-out-paths --impure --expr "
      let
        flake = builtins.getFlake \"path:$ROOT\";
        pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
      in
        pkgs.callPackage $ROOT/modules/core/aarambh/package.nix {
          palette = {
            paper = \"3c3836\";
            ink = \"ebdbb2\";
            accent = \"98971a\";
            # 65% of paper, the same as the module's scaleHex.
            paperDark = \"272423\";
          };
        }
    "
}

# Builds a fake loader that writes $2 to its volume, then shuts down. The flags
# match Aarambh's Makefile exactly: a gnu-efi app built with -O0 or the wrong
# library order misbehaves in the firmware (hangs and crashes instead of a
# clean status).
build_marker() {
    local name=$1 marker=$2
    local inc="$GNU_EFI/include/efi" lib="$GNU_EFI/lib"

    gcc -I"$inc" -I"$inc/x86_64" -I"$inc/protocol" \
        -DMARKER_NAME="L\"$marker\"" -DGNU_EFI_USE_MS_ABI -DEFI_FUNCTION_WRAPPER \
        -O2 -std=gnu11 -fpic -fshort-wchar -ffreestanding \
        -fno-stack-protector -fno-strict-aliasing -fno-stack-check \
        -mno-red-zone -maccumulate-outgoing-args -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 \
        -Wall -Wextra -Wno-unused-parameter \
        -c "$TEST_DIR/marker.c" -o "$WORK/$name.o"
    ld -nostdlib -znocombreloc -T "$lib/elf_x86_64_efi.lds" -shared -Bsymbolic -L"$lib" \
        "$lib/crt0-efi-x86_64.o" "$WORK/$name.o" -lefi -lgnuefi -o "$WORK/$name.so"
    objcopy -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym -j .rel -j .rela -j .rel.* \
        -j .reloc -j .sbat -O efi-app-x86_64 --subsystem=10 "$WORK/$name.so" "$WORK/$name.efi"
}

# Creates a GPT disk with one FAT partition that has the given PARTUUID.
make_disk() {
    local file=$1 partuuid=$2 fat="$WORK/fat.img"

    rm -f "$file"
    truncate -s 128M "$file"
    sgdisk -Z -n 1:2048:+96M -t 1:EF00 -u "1:$partuuid" -c 1:ESP "$file" >/dev/null
    rm -f "$fat"
    mkfs.vfat -C "$fat" $((96 * 1024)) >/dev/null
    dd if="$fat" of="$file" bs=512 seek=2048 conv=notrunc status=none
}

provision_desktop() {
    local img="$1@@$OFFSET" menu="$AARAMBH_OUT/share/aarambh"

    mmd -i "$img" ::/EFI ::/EFI/BOOT ::/EFI/aarambh ::/EFI/SYSTEMD
    mcopy -i "$img" "$menu/aarambh.efi" ::/EFI/BOOT/BOOTX64.EFI
    mcopy -i "$img" "$menu/aarambh.efi" ::/EFI/aarambh/aarambh.efi
    mcopy -s -i "$img" "$menu/fonts" "$menu/logos" "$menu/backgrounds" ::/EFI/aarambh/
    # The own-systemd-boot slot holds a marker loader: a schedule case that
    # falls back to the plain default should start it.
    mcopy -i "$img" "$WORK/deskboot.efi" ::/EFI/SYSTEMD/SYSTEMD-BOOTX64.EFI
}

provision_work() {
    local img="$1@@$OFFSET"

    mmd -i "$img" ::/EFI ::/EFI/MICROSOFT ::/EFI/MICROSOFT/BOOT ::/EFI/SYSTEMD
    mcopy -i "$img" "$WORK/winboot.efi" ::/EFI/MICROSOFT/BOOT/BOOTMGFW.EFI
    mcopy -i "$img" "$WORK/workboot.efi" ::/EFI/SYSTEMD/SYSTEMD-BOOTX64.EFI
}

wait_for_socket() {
    local sock=$1
    for _ in $(seq 1 50); do
        if [ -S "$sock" ]; then
            return 0
        fi
        sleep 0.2
    done
    return 1
}

# run_case <name> <fixture> <default key> <rtc or ""> <want volume> <want marker>
# Exactly one marker may be written: the wanted one, on its volume.
run_case() {
    local name=$1 fixture=$2 default=$3 rtc=$4 want_volume=$5 marker=$6
    local desk="$WORK/$name-desktop.img" work="$WORK/$name-work.img"
    local vars="$WORK/$name-vars.fd" sock="$WORK/$name.sock" log="$WORK/$name.log"
    local shot="$WORK/$name.ppm" pid waited theme_ok=0
    local -a clock=()

    if [ -n "$rtc" ]; then
        clock=(-rtc "base=$rtc")
    fi

    echo "== $name: default $default, rtc ${rtc:-now}, expecting $marker on the ${want_volume} ESP"

    cp "$WORK/base-desktop.img" "$desk"
    cp "$WORK/base-work.img" "$work"
    cp "$OVMF_VARS" "$vars"
    chmod u+w "$vars"
    sed "s/@DEFAULT@/$default/" "$TEST_DIR/fixtures/$fixture" >"$WORK/$name.conf"
    mcopy -o -i "$desk@@$OFFSET" "$WORK/$name.conf" ::/EFI/aarambh/aarambh.conf

    rm -f "$sock" "$shot"
    qemu-system-x86_64 \
        -no-reboot -machine q35 -m 1024 "${clock[@]}" \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
        -drive if=pflash,format=raw,file="$vars" \
        -drive if=none,id=desktop,format=raw,file="$desk" \
        -device virtio-blk-pci,drive=desktop \
        -drive if=none,id=work,format=raw,file="$work" \
        -device virtio-blk-pci,drive=work \
        -vga std -display none -serial none \
        -monitor "unix:$sock,server,nowait" >"$log" 2>&1 &
    pid=$!

    if ! wait_for_socket "$sock"; then
        kill "$pid" 2>/dev/null || true
        fail "$name: QEMU monitor socket did not appear, see $log"
        return
    fi

    # The menu draws after OVMF starts, which can take a while under emulation.
    for _ in $(seq 1 45); do
        sleep 2
        "$TEST_DIR/screen.sh" dump "$sock" "$shot" >/dev/null 2>&1 || true
        if [ -s "$shot" ] && "$TEST_DIR/screen.sh" check "$shot"; then
            theme_ok=1
            break
        fi
    done
    if [ "$theme_ok" = 0 ]; then
        fail "$name: the menu did not show the editorial-gruvbox colours, see $shot"
    fi

    # The menu counts down, starts the default and the fake loader shuts down.
    waited=0
    while kill -0 "$pid" 2>/dev/null; do
        sleep 2
        waited=$((waited + 2))
        if [ "$waited" -ge 240 ]; then
            kill "$pid" 2>/dev/null || true
            fail "$name: the VM did not shut down after the default entry started"
            break
        fi
    done
    wait "$pid" 2>/dev/null || true

    # Exactly one marker across both volumes, and it is the expected one.
    found=""
    for probe in WORKBOOT.TXT WINBOOT.TXT DESKBOOT.TXT; do
        if mtype -i "$desk@@$OFFSET" "::/$probe" >/dev/null 2>&1; then
            found="$found desktop:$probe"
        fi
        if mtype -i "$work@@$OFFSET" "::/$probe" >/dev/null 2>&1; then
            found="$found work:$probe"
        fi
    done

    if [ "$found" = " $want_volume:$marker" ]; then
        echo "ok: $marker written to the $want_volume ESP"
    else
        fail "$name: expected only $want_volume:$marker, got${found:- nothing}, see $log"
    fi
}

main() {
    mkdir -p "$WORK"
    rm -f "$WORK"/*.log "$WORK"/*.img "$WORK"/*.ppm "$WORK"/*.conf

    AARAMBH_OUT="$(build_package)"
    GNU_EFI="$(nix build --no-link --print-out-paths nixpkgs#gnu-efi)"
    OVMF_DIR="$(nix build --no-link --print-out-paths nixpkgs#OVMF.fd)/FV"
    OVMF_CODE="$OVMF_DIR/OVMF_CODE.fd"
    OVMF_VARS="$OVMF_DIR/OVMF_VARS.fd"
    export AARAMBH_OUT GNU_EFI OVMF_CODE OVMF_VARS

    if [ ! -f "$OVMF_CODE" ] || [ ! -f "$OVMF_VARS" ]; then
        echo "OVMF firmware not found in $OVMF_DIR" >&2
        exit 1
    fi

    build_marker workboot WORKBOOT.TXT
    build_marker winboot WINBOOT.TXT
    build_marker deskboot DESKBOOT.TXT

    make_disk "$WORK/base-desktop.img" "$DESKTOP_PARTUUID"
    make_disk "$WORK/base-work.img" "$WORK_PARTUUID"
    provision_desktop "$WORK/base-desktop.img"
    provision_work "$WORK/base-work.img"

    run_case explicit-work aarambh.conf nixos-work "" work WORKBOOT.TXT
    run_case explicit-windows aarambh.conf windows "" work WINBOOT.TXT
    run_case autodetect-systemd aarambh-autodetect.conf systemd-boot "" work WORKBOOT.TXT
    run_case autodetect-windows aarambh-autodetect.conf windows "" work WINBOOT.TXT
    # 2026-11-16 is a Monday. Inside the window the work install starts by
    # itself; outside it the plain default (this desktop's NixOS) does.
    run_case schedule-monday-day aarambh-schedule.conf nixos 2026-11-16T10:00:00 work WORKBOOT.TXT
    run_case schedule-monday-evening aarambh-schedule.conf nixos 2026-11-16T20:00:00 desktop DESKBOOT.TXT

    if [ "$FAILURES" -eq 0 ]; then
        echo "PASS: all Aarambh QEMU cases"
    else
        echo "FAILED: $FAILURES check(s) failed, see $WORK"
        exit 1
    fi
}

main "$@"
