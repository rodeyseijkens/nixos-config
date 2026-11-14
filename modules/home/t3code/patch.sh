#!/usr/bin/env bash
#
# Gives T3 Code Gruvbox syntax and diff accents.
#
# T3 Code hardcodes syntax highlighting to the Pierre palettes
# (`pierre-dark` / `pierre-light` -> `t3-light`) instead of following the
# selected app theme. The app already bundles the Zed Gruvbox themes, so we
# swap the Pierre theme payloads for their Gruvbox counterparts and align the
# diff accents with Codey's Gruvbox colors.
#
# Everything is rewritten in place and padded to its original size, so asar
# offsets stay valid. Integrity hashes are recomputed for changed files.
#
# Usage: patch.sh path/to/app.asar

set -euo pipefail
shopt -s nullglob
export LC_ALL=C

TARGET_DARK="gruvbox-dark-hard"
TARGET_LIGHT="gruvbox-light-medium"

# Pierre theme id -> Gruvbox theme id it is replaced with.
THEME_TARGETS=(pierre-dark pierre-light)
THEME_SOURCES=("$TARGET_DARK" "$TARGET_LIGHT")

# Codey's Gruvbox diff accents (src/ui/theme/codey.ts).
DIFF_KEYS=(
    addition-override
    addition-number-override
    addition-hover-override
    addition-emphasis-override
    deletion-override
    deletion-number-override
    deletion-hover-override
    deletion-emphasis-override
)
DIFF_VALUES=(
    "light-dark(#e2e8c2, #2d4a2d)"
    "light-dark(#dbe3bb, #345234)"
    "light-dark(#d9e0b3, #365a36)"
    "light-dark(#d3dca8, #3b613b)"
    "light-dark(#f9d8d4, #4a2d2d)"
    "light-dark(#f3c7c1, #543030)"
    "light-dark(#f5cfca, #523131)"
    "light-dark(#efc0ba, #5a3333)"
)

DIFF_TEXT_OLD="--diff-addition:var(--success);--diff-deletion:var(--destructive);--diff-addition-foreground:var(--lightningcss-light,var(--color-emerald-700))var(--lightningcss-dark,var(--color-emerald-400));--diff-deletion-foreground:var(--lightningcss-light,var(--color-red-700))var(--lightningcss-dark,var(--color-red-400))}"
DIFF_TEXT_NEW="--diff-addition:light-dark(#79740e,#b8bb26);--diff-deletion:light-dark(#9d0006,#fb4934);--diff-addition-foreground:var(--diff-addition);--diff-deletion-foreground:var(--diff-deletion)}"

# Theme chunks at most this big are searched; larger files are never themes.
MAX_THEME_BYTES=200000
# asar blocks, unless the header says otherwise.
DEFAULT_BLOCK_SIZE=4194304

die() {
    echo "$*" >&2
    exit 1
}

# Escapes text for use inside a sed BRE pattern.
re_escape() {
    printf '%s' "$1" | sed -e 's/[][\.*^$/]/\\&/g'
}

# Escapes text for use in a sed replacement.
repl_escape() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

# Runs one sed expression over a file, replacing the first match only. The
# whole file is one record (-z), so "first" means first in the file.
sed_first() {
    local expr=$1 file=$2
    sed -z "$expr" "$file" >"$file.next"
    mv -f "$file.next" "$file"
}

# Prints the value of a field of the entry at the given JSON path.
entry_json() {
    local header=$1 pathjson=$2 program=$3
    jq -r --argjson p "$pathjson" "getpath(\$p) | $program" "$header"
}

# Prints the blocks JSON array (SHA256 per block of blockSize bytes) of a file.
sha256_blocks() {
    local block_size=$1 file=$2 dir
    dir=$(mktemp -d "$WORK/blocks.XXXXXX")
    split -b "$block_size" -d -a 6 "$file" "$dir/b."
    for part in "$dir"/b.*; do
        sha256sum "$part" | cut -d' ' -f1
    done | jq -R . | jq -sc .
    rm -rf "$dir"
}

# Sets the entry at the given JSON path to a new integrity hash and blocks.
set_integrity() {
    local header=$1 pathjson=$2 digest=$3 blocks=$4 tmp
    tmp="$header.next"
    jq -c --argjson p "$pathjson" --arg digest "$digest" --argjson blocks "$blocks" '
        setpath($p + ["integrity", "hash"]; $digest)
        | setpath($p + ["integrity", "blocks"]; $blocks)
    ' "$header" >"$tmp"
    mv -f "$tmp" "$header"
}

# Writes the first match of a theme name, the way patch_theme_text did.
# textmate: "name": "<gruvbox>" becomes "name":"<target>".
# zed: name:`<gruvbox>` (the first literal occurrence) becomes name:`<target>`.
patch_theme() {
    local kind=$1 gruvbox=$2 target=$3 src=$4 out=$5 match name
    cp "$src" "$out"
    if [ "$kind" = textmate ]; then
        local pattern
        pattern="\"name\"[[:space:]]*:[[:space:]]*\"$(re_escape "$gruvbox")\""
        grep -zq -- "$pattern" "$src" || die "missing TextMate name '$gruvbox'"
        sed_first "s/$pattern/\"name\":\"$(repl_escape "$target")\"/" "$out"
        return
    fi

    # shellcheck disable=SC2016 # a PCRE pattern, with backticks literal
    match=$(grep -zoP 'name\s*:\s*`[^`]+`' "$src" | head -z -n 1 | tr -d '\0') || true
    [ -n "$match" ] || die "cannot find Zed theme name in $gruvbox"
    name=${match#*\`}
    name=${name%\`}
    sed_first "s/$(re_escape "name:\`$name\`")/$(repl_escape "name:\`$target\`")/" "$out"
}

main() {
    [ "$#" -eq 1 ] || die "usage: patch.sh path/to/app.asar"
    local archive=$1
    local magic header_size json_size base
    local header path pathjson size offset unpacked n file
    local catalog js kind target_info source_info target_path source_file out
    local i key value cur digest blocks bs alg padded len patched_diff patched_text

    WORK=$(mktemp -d)
    trap 'rm -rf "$WORK"' EXIT

    # The archive starts with four little-endian uint32s: magic, header size,
    # payload size and the length of the JSON header that follows.
    read -r magic header_size _ json_size < <(od -An -tu4 --endian=little -N16 "$archive")
    [ "$magic" -eq 4 ] || die "unexpected asar header magic: $magic"
    base=$((8 + header_size))

    header="$WORK/header.json"
    dd if="$archive" iflag=skip_bytes,count_bytes skip=16 count="$json_size" status=none >"$header"

    # Every file in the archive, depth first: path, JSON path, size, offset and
    # whether it is stored unpacked outside the archive.
    local leaves="$WORK/leaves.tsv"
    jq -r '
        paths as $p
        | select($p | length > 1 and $p[-2] == "files")
        | getpath($p) as $e
        | select(($e | type) == "object" and ($e | has("size")) and (($e | has("files")) | not))
        | [
            "/" + ([range(1; $p | length; 2) | $p[.]] | join("/")),
            ($p | tojson),
            ($e.size | tostring),
            (($e.offset // "0") | tonumber | tostring),
            (($e.unpacked // false) | tostring)
          ]
        | @tsv
    ' "$header" >"$leaves"

    # Pass 1: read the JS and CSS files, and sort the JS theme chunks into the
    # textmate and zed catalogs. Files are read once and kept in $WORK.
    js="$WORK/js.tsv"
    catalog="$WORK/catalog.tsv"
    : >"$js"
    : >"$catalog"
    declare -gA LEAF_JSON=() LEAF_SIZE=() LEAF_OFFSET=()
    n=0
    while IFS=$'\t' read -r path pathjson size offset unpacked; do
        n=$((n + 1))
        [ "$unpacked" = false ] || continue
        case "$path" in
        *.js | *.css) ;;
        *) continue ;;
        esac
        file="$WORK/leaf-$n"
        dd if="$archive" iflag=skip_bytes,count_bytes skip=$((base + offset)) count="$size" status=none >"$file"
        printf '%s\t%s\t%s\t%s\t%s\n' "$path" "$pathjson" "$size" "$offset" "$file" >>"$js"
        LEAF_JSON[$path]=$pathjson
        LEAF_SIZE[$path]=$size
        LEAF_OFFSET[$path]=$offset

        case "$path" in *.js) ;; *) continue ;; esac
        [ "$size" -le "$MAX_THEME_BYTES" ] || continue
        # shellcheck disable=SC2016 # the patterns below have literal backticks
        if grep -qF -- 'Object.freeze(JSON.parse(`' "$file"; then
            kind=textmate
        elif grep -zqP '(?s)name\s*:\s*`[^`]+`.*style\s*:' "$file"; then
            kind=zed
        else
            continue
        fi
        printf '%s\t%s\t%s\n' "$kind" "$path" "$file" >>"$catalog"
    done <"$leaves"

    # The first chunk whose hashed file name starts with the theme id.
    find_theme() {
        local want=$1 theme=$2 k p f stem
        while IFS=$'\t' read -r k p f; do
            [ "$k" = "$want" ] || continue
            stem=${p##*/}
            stem=${stem%.js}
            case "$stem" in
            "$theme"-*)
                printf '%s\t%s\n' "$p" "$f"
                return 0
                ;;
            esac
        done <"$catalog"
        return 1
    }

    declare -A UPDATES=()
    for i in "${!THEME_TARGETS[@]}"; do
        local theme_target=${THEME_TARGETS[i]} theme_source=${THEME_SOURCES[i]}
        for kind in textmate zed; do
            target_info=$(find_theme "$kind" "$theme_target") || die "missing $kind theme pair for $theme_target / $theme_source"
            source_info=$(find_theme "$kind" "$theme_source") || die "missing $kind theme pair for $theme_target / $theme_source"
            target_path=${target_info%%$'\t'*}
            source_file=${source_info##*$'\t'}
            out="$WORK/theme-$theme_target-$kind.js"
            patch_theme "$kind" "$theme_source" "$theme_target" "$source_file" "$out"
            UPDATES[$target_path]=$out
        done
    done

    # Pass 2: the diff renderer's background overrides and the stylesheet's
    # accent variables. A file changed here replaces any theme change to it,
    # as the Python version did.
    patched_diff=0
    patched_text=0
    while IFS=$'\t' read -r path pathjson size offset file; do
        cur="$WORK/diff-cur"
        cp "$file" "$cur"
        if grep -qF -- '--diffs-bg-addition-override' "$file"; then
            for i in "${!DIFF_KEYS[@]}"; do
                key=${DIFF_KEYS[i]}
                value=${DIFF_VALUES[i]}
                if grep -zq -- "--diffs-bg-$(re_escape "$key")[[:space:]]*:[^;]*;" "$cur"; then
                    sed_first "s/--diffs-bg-$(re_escape "$key")[[:space:]]*:[^;]*;/--diffs-bg-$key: $(repl_escape "$value");/" "$cur"
                    patched_diff=1
                fi
            done
        fi
        if grep -qF -- "$DIFF_TEXT_OLD" "$file"; then
            sed_first "s/$(re_escape "$DIFF_TEXT_OLD")/$(repl_escape "$DIFF_TEXT_NEW")/" "$cur"
            patched_text=1
        fi
        if ! cmp -s "$cur" "$file"; then
            out="$file.patched"
            mv -f "$cur" "$out"
            UPDATES[$path]=$out
        fi
    done <"$js"

    [ "$patched_diff" -eq 1 ] || die "missing diff background overrides in diff renderer"
    [ "$patched_text" -eq 1 ] || die "missing diff accent variables in stylesheet"

    # Write each changed file back at its offset, padded with spaces to its
    # original size, with new integrity hashes in the header.
    for path in "${!UPDATES[@]}"; do
        pathjson=${LEAF_JSON[$path]}
        size=${LEAF_SIZE[$path]}
        offset=${LEAF_OFFSET[$path]}
        cur=${UPDATES[$path]}

        # shellcheck disable=SC2016 # jq variables, not shell ones
        alg=$(entry_json "$header" "$pathjson" '((.integrity | objects | .algorithm) // "") | ascii_upcase')
        [ "$alg" = SHA256 ] || die "$path: unsupported integrity $(entry_json "$header" "$pathjson" '.integrity | tojson')"
        bs=$(entry_json "$header" "$pathjson" ".integrity.blockSize // $DEFAULT_BLOCK_SIZE")

        len=$(stat -c %s "$cur")
        [ "$len" -le "$size" ] || die "$path: $len bytes exceeds original $size"
        padded="$WORK/padded"
        cp "$cur" "$padded"
        if [ "$len" -lt "$size" ]; then
            head -c $((size - len)) /dev/zero | tr '\0' ' ' >>"$padded"
        fi

        digest=$(sha256sum "$padded" | cut -d' ' -f1)
        blocks=$(sha256_blocks "$bs" "$padded")
        set_integrity "$header" "$pathjson" "$digest" "$blocks"
        dd if="$padded" of="$archive" oflag=seek_bytes seek=$((base + offset)) conv=notrunc status=none
    done

    # The new header must be exactly as long as the old one, or the archive's
    # offsets would move.
    local new_header="$WORK/new-header.json"
    jq -c -j . "$header" >"$new_header"
    [ "$(stat -c %s "$new_header")" -eq "$json_size" ] ||
        die "refusing to rewrite asar header: $(stat -c %s "$new_header") != $json_size bytes"
    dd if="$new_header" of="$archive" oflag=seek_bytes seek=16 conv=notrunc status=none

    echo "patched ${#UPDATES[@]} files in $archive"
}

main "$@"
