# shellcheck shell=bash
# Installs, updates and removes the Aarambh menu on one ESP.
#
# The NixOS module runs "install" from the systemd-boot install hook, and
# "remove" when aarambh.enable is false. aarambh-uninstall runs "remove" by
# hand. The @...@ placeholders below are filled in by modules/core/aarambh.nix.
#
# Files are staged in <esp>/EFI/aarambh.staging and swapped in, so a failed run
# keeps the last complete menu. Firmware entries are found by content (ESP
# PARTUUID plus loader path), never by boot number.

set -euo pipefail

AARAMBH_SHARE="@share@"
CONF="@conf@"
DEFAULT_PARTUUID="@partuuid@"
MARKER=".nixos-managed"
AARAMBH_LOADER='\EFI\aarambh\aarambh.efi'
SYSTEMD_BOOT_LOADER='\EFI\systemd\systemd-bootx64.efi'

ESP=/boot
PARTUUID="$DEFAULT_PARTUUID"
action=""

die() {
    echo "aarambh: $*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: aarambh-esp install|remove [--esp MOUNT] [--partuuid GUID]

  install   write the menu to the ESP and make Aarambh the first boot entry
  remove    make systemd-boot the first boot entry, delete the Aarambh firmware
            entry and its files; does nothing unless the ESP has the marker

  --esp       mount point of the ESP (default: /boot)
  --partuuid  PARTUUID the ESP must have (default: the desktop's)
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        install | remove) action=$1 ;;
        --esp)
            ESP=${2:?--esp needs a mount point}
            shift
            ;;
        --partuuid)
            PARTUUID=${2:?--partuuid needs a GUID}
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [ -z "$action" ]; then
    usage >&2
    exit 2
fi

if [ -z "$PARTUUID" ]; then
    die "no ESP PARTUUID known here, pass --partuuid"
fi

ESP_EFI="$ESP/EFI"

# The ESP must be mounted, and it must be the partition with the given PARTUUID.
check_esp() {
    local source partuuid

    if ! source=$(findmnt -no SOURCE --mountpoint "$ESP"); then
        die "$ESP is not mounted"
    fi

    partuuid=$(lsblk -no PARTUUID "$source" | head -n1 | tr '[:upper:]' '[:lower:]')
    if [ "$partuuid" != "${PARTUUID,,}" ]; then
        die "$ESP is $source (PARTUUID ${partuuid:-unknown}), not PARTUUID $PARTUUID"
    fi
}

# Prints the boot number (e.g. 0007) of the firmware entry that starts the
# loader $2 from the ESP with PARTUUID $1. Prints nothing when there is none.
find_boot_entry() {
    efibootmgr -v | PART="${1,,}" FILE="${2,,}" awk '
        /^Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/ {
            line = tolower($0)
            if (index(line, "gpt," ENVIRON["PART"] ",") > 0 && index(line, "file(" ENVIRON["FILE"] ")") > 0) {
                print substr($1, 5, 4)
                exit
            }
        }'
}

# Puts the given boot numbers first, in the given order, then the rest of the
# current BootOrder.
set_boot_order() {
    local -a order=("$@")
    local -a rest=()
    local number first skip

    while read -r number; do
        [ -n "$number" ] || continue
        skip=0
        for first in "${order[@]}"; do
            if [ "$first" = "$number" ]; then
                skip=1
            fi
        done
        if [ "$skip" = 0 ]; then
            rest+=("$number")
        fi
    done < <(efibootmgr | sed -n 's/^BootOrder: //p' | tr ',' '\n')

    local IFS=,
    efibootmgr -o "${order[*]}${rest[*]:+,${rest[*]}}" >/dev/null
}

# Adds the Aarambh firmware entry for the ESP that is mounted at $ESP.
create_firmware_entry() {
    local source disk part

    source=$(findmnt -no SOURCE --mountpoint "$ESP")
    disk="/dev/$(lsblk -no PKNAME "$source" | head -n1)"
    part=$(cat "/sys/class/block/$(basename "$source")/partition")

    efibootmgr -c -d "$disk" -p "$part" -L Aarambh -l "$AARAMBH_LOADER" >/dev/null
}

# Prints one BootLoaderSpec field value, e.g. the linux line of an entry.
bls_field() {
    sed -n "s/^$1[[:space:]]\\+//p" "$2" | head -n1
}

bls_all() {
    sed -n "s/^$1[[:space:]]\\+//p" "$2"
}

# Turns ESP-relative slash paths (/EFI/nixos/x.efi) into UEFI paths.
uefi_path() {
    sed -e 's#/#\\#g'
}

# Writes the kernel list: the loader's oneshot line first, then one
# title|id|kernel|initrd|cmdline line per generation, newest first. The kernels
# are the files systemd-boot already keeps under EFI/nixos, so nothing is copied.
write_kernels() {
    local entry id title kernel initrd options count=0

    echo "@oneshot systemd-boot"
    while read -r entry; do
        kernel=$(bls_field linux "$entry")
        if [ -z "$kernel" ]; then
            continue
        fi

        id=$(basename "$entry" .conf)
        title=$(bls_field title "$entry")
        initrd=$(bls_all initrd "$entry" | uefi_path | paste -sd, -)
        options=$(bls_field options "$entry")
        printf '%s|%s|%s|%s|%s\n' "$title" "$id" "$(echo "$kernel" | uefi_path)" "$initrd" "$options"
        count=$((count + 1))
    done < <(find "$ESP/loader/entries" -maxdepth 1 -name '*.conf' 2>/dev/null | sort -rV)

    if [ "$count" -eq 0 ]; then
        die "no boot entries with a kernel in $ESP/loader/entries"
    fi
}

# Builds the whole menu in a staging directory, next to the live one.
stage_menu() {
    local staging="$ESP_EFI/aarambh.staging"

    rm -rf "$staging"
    install -d "$staging"

    cp -r --no-preserve=mode "$AARAMBH_SHARE/aarambh.efi" "$AARAMBH_SHARE/fonts" \
        "$AARAMBH_SHARE/logos" "$AARAMBH_SHARE/backgrounds" "$staging/"
    install -m 0644 "$CONF" "$staging/aarambh.conf"
    write_kernels >"$staging/nixos.kernels"
    printf 'Managed by the NixOS aarambh module. Remove with aarambh-uninstall.\n' >"$staging/$MARKER"
}

# Replaces the live menu with the staged one. The old directory is removed only
# after the new one is in place.
swap_menu() {
    rm -rf "$ESP_EFI/aarambh.previous"
    if [ -d "$ESP_EFI/aarambh" ]; then
        mv "$ESP_EFI/aarambh" "$ESP_EFI/aarambh.previous"
    fi
    mv "$ESP_EFI/aarambh.staging" "$ESP_EFI/aarambh"
    rm -rf "$ESP_EFI/aarambh.previous"
}

install_menu() {
    local entry systemd_boot

    check_esp

    if [ -d "$ESP_EFI/aarambh" ] && [ ! -f "$ESP_EFI/aarambh/$MARKER" ]; then
        die "$ESP_EFI/aarambh exists and is not managed by NixOS, move it away first"
    fi

    entry=$(find_boot_entry "$PARTUUID" "$AARAMBH_LOADER")
    if [ -z "$entry" ]; then
        create_firmware_entry
        entry=$(find_boot_entry "$PARTUUID" "$AARAMBH_LOADER")
    fi
    if [ -z "$entry" ]; then
        die "could not find or create the Aarambh firmware entry"
    fi

    stage_menu
    swap_menu

    systemd_boot=$(find_boot_entry "$PARTUUID" "$SYSTEMD_BOOT_LOADER")
    if [ -n "$systemd_boot" ]; then
        set_boot_order "$entry" "$systemd_boot"
    else
        set_boot_order "$entry"
    fi

    echo "aarambh: menu installed on $ESP, Aarambh is the first boot entry"
}

remove_menu() {
    local entry systemd_boot

    check_esp

    if [ ! -f "$ESP_EFI/aarambh/$MARKER" ]; then
        echo "aarambh: no NixOS-managed menu on $ESP, nothing to remove"
        return 0
    fi

    systemd_boot=$(find_boot_entry "$PARTUUID" "$SYSTEMD_BOOT_LOADER")
    if [ -n "$systemd_boot" ]; then
        set_boot_order "$systemd_boot"
    fi

    entry=$(find_boot_entry "$PARTUUID" "$AARAMBH_LOADER")
    if [ -n "$entry" ]; then
        efibootmgr -b "$entry" -B >/dev/null
    fi

    rm -rf "$ESP_EFI/aarambh"
    echo "aarambh: removed from $ESP"
}

case "$action" in
    install) install_menu ;;
    remove) remove_menu ;;
esac
