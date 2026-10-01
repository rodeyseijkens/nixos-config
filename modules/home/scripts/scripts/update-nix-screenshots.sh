#!/usr/bin/env bash
# update-screenshots - re-stage and re-capture the README screenshots
# (.github/assets/screenshots/{1,2,3}.png) with the current desktop setup.
#
# Everything is staged on a scratch workspace (default: 7), captured with
# grimblast, and closed again afterwards.
#
# Usage: update-screenshots [repo-dir]
# Env:   SCREENSHOT_WORKSPACE  staging workspace (default 7)
#        SCREENSHOT_REPO       repo dir if not given as argument

set -euo pipefail

WS="${SCREENSHOT_WORKSPACE:-7}"
REPO_DIR="${1:-${SCREENSHOT_REPO:-$HOME/nixos-config}}"
OUT_DIR="$REPO_DIR/.github/assets/screenshots"
TERM_BIN="ghostty"
VSCODE_FILE="modules/home/vscode/vscode.nix"

die() { echo "update-screenshots: $*" >&2; exit 1; }

[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || die "not inside a Hyprland session"
[ -d "$OUT_DIR" ] || die "screenshot directory not found: $OUT_DIR"

for cmd in hyprctl jq grimblast "$TERM_BIN" nautilus code walker qs \
    notify-send fastfetch onefetch cmatrix cbonsai tty-clock btop starship zsh awww; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing dependency: $cmd"
done

# workspace must be empty so we never touch user windows
open_count=$(hyprctl clients -j | jq --argjson ws "$WS" '[.[] | select(.workspace.id == $ws)] | length')
[ "$open_count" -eq 0 ] || die "workspace $WS is not empty ($open_count windows), aborting"

# --- state used by the cleanup trap ---
STAGED_ADDRS=()
WALKER_OPEN=0
PANEL_OPEN=0
ORIG_WS=$(hyprctl activeworkspace -j | jq -r .id)
STAGE_DIR=$(mktemp -d)
STAGE_MON=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
FOA=$(hyprctl getoption -j misc:focus_on_activate | jq -r '.int')
# current wallpaper of the staging monitor, restored on exit
ORIG_WALL=$(awww query | sed -n "s/^: $STAGE_MON: .*currently displaying: image: //p")
WALL_DIR="$REPO_DIR/wallpapers/gruvbox"
FOA_BOOL=$([ "$FOA" = 1 ] && echo true || echo false)

# Hyprland ≥0.55 Lua configs no longer accept legacy `hyprctl dispatch`/`keyword`
# syntax; shim to the hl.dsp/hl.config forms (see hyprland/hyprland-util.nix).
hd() { # hd <dispatcher lua> — hl.dsp.* call, quoted for the Lua parser
    hyprctl dispatch "$1" >/dev/null
}
hws() { # hws <id> — focus workspace
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$1\" })" >/dev/null
}
hclose() { # hclose <address> — close window by address
    hyprctl dispatch "hl.dsp.window.close({ window = 'address:$1' })" >/dev/null 2>&1 || true
}
# don't let apps on other monitors steal focus while we stage windows
hyprctl eval 'hl.config({ misc = { focus_on_activate = false } })' >/dev/null

cleanup() {
    [ "$WALKER_OPEN" = 1 ] && walker -q >/dev/null 2>&1 || true
    [ "$PANEL_OPEN" = 1 ] && qs -c shell ipc call notif close >/dev/null 2>&1 || true
    for addr in ${STAGED_ADDRS[@]:-}; do
        hclose "$addr"
    done
    hyprctl eval "hl.config({ misc = { focus_on_activate = $FOA_BOOL } })" >/dev/null 2>&1 || true
    [ -n "${ORIG_WALL:-}" ] && awww img -o "$STAGE_MON" --transition-type none "$ORIG_WALL" >/dev/null 2>&1 || true
    hws "$ORIG_WS" >/dev/null 2>&1 || true
    rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

# monitor geometry of the focused output (the one we stage on and capture)
read -r MX MY MW MH < <(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.x) \(.y) \(.width/.scale|floor) \(.height/.scale|floor)"')

px() { echo $(($1 * $2 / 100)); } # px <total> <percent>

ensure_ws() {
    if [ "$(hyprctl activeworkspace -j | jq -r .id)" != "$WS" ]; then
        hws "$WS"
        sleep 0.4
    fi
}

LAST_ADDR=""
open_app() { # open_app <cmd...> - exec and wait for the new window, sets LAST_ADDR
    local before addr
    before=$(hyprctl clients -j | jq -r '.[].address' | sort)
    hd "hl.dsp.exec_cmd('$*')"
    for _ in $(seq 1 100); do
        sleep 0.2
        addr=$(comm -13 \
            <(echo "$before") \
            <(hyprctl clients -j | jq -r --argjson ws "$WS" '.[] | select(.workspace.id == $ws) | .address' | sort) |
            head -n1)
        if [ -n "$addr" ]; then
            STAGED_ADDRS+=("$addr")
            LAST_ADDR="$addr"
            return 0
        fi
    done
    die "timed out waiting for window: $*"
}

focus_window() {
    hyprctl dispatch "hl.dsp.focus({ window = hl.get_window('address:$1') })" >/dev/null
    sleep 0.2
}

close_window() {
    hclose "$1"
    sleep 0.4
}

set_wallpaper() { # set_wallpaper <file in $WALL_DIR> - instant, staging monitor only
    [ -f "$WALL_DIR/$1" ] || die "wallpaper not found: $WALL_DIR/$1"
    awww img -o "$STAGE_MON" --transition-type none "$WALL_DIR/$1" >/dev/null
    sleep 0.5
}

park_cursor() {
    hyprctl dispatch "hl.dsp.cursor.move({ x = $((MX + 20)), y = $((MY + 20)) })" >/dev/null
}

capture() { # capture <filename> [hero window address]
    local hero="${2:-}"
    ensure_ws
    # grimblast captures the focused monitor; make sure that's the staging one
    for _ in $(seq 1 8); do
        [ "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" = "$STAGE_MON" ] && break
        if [ -n "$hero" ]; then
            focus_window "$hero"
        else
            hws "$WS"
        fi
        sleep 0.4
    done
    park_cursor
    echo "capturing $1 in 5s (last chance to close anything)..."
    sleep 5
    grimblast save output "$OUT_DIR/$1"
    echo "captured $OUT_DIR/$1"
}

# ---------------------------------------------------------------- shot 1 ---
# nautilus (floating, top left) + walker launcher + quickshell notification panel
shot1() {
    echo "== shot 1: nautilus + walker + quickshell =="
    ensure_ws
    set_wallpaper astronaut.jpg

    open_app nautilus
    local naut=$LAST_ADDR
    hyprctl dispatch "hl.dsp.window.float({ window = 'address:$naut' })" >/dev/null
    hyprctl dispatch "hl.dsp.window.resize({ x = $(px "$MW" 41), y = $(px "$MH" 44), exact = true, window = 'address:$naut' })" >/dev/null
    hyprctl dispatch "hl.dsp.window.move({ x = $(px "$MW" 3), y = $(px "$MH" 6), exact = true, window = 'address:$naut' })" >/dev/null
    focus_window "$naut"
    sleep 2.5

    # content for the notification panel (newest first)
    # -t 1: popup expires instantly, but the notification stays in the panel
    qs -c shell ipc call notif clear # start from a clean panel
    sleep 0.5        # the clear is async; give it time before sending
    # different urgencies = different border colors in the panel (see NotifCard.qml)
    notify-send -t 1 -u low "Hello" "there"
    sleep 0.4
    notify-send -t 1 -u normal "You" "fellow"
    sleep 0.4
    notify-send -t 1 -u critical "Nix" "enjoyer"
    sleep 0.4

    walker --maxheight 300 --minheight 300 &
    WALKER_OPEN=1
    sleep 1.2
    qs -c shell ipc call notif open
    PANEL_OPEN=1
    sleep 1

    park_cursor
    capture 1.png "$naut"

    walker -q
    WALKER_OPEN=0
    qs -c shell ipc call notif close
    PANEL_OPEN=0
    close_window "$naut"
}

# ---------------------------------------------------------------- shot 2 ---
# vscode (left, repo open) + terminal (right, staged git/build info)
shot2() {
    echo "== shot 2: vscode + terminal =="
    ensure_ws
    set_wallpaper mountain_valley.jpg

    cat >"$STAGE_DIR/term-info.zsh" <<'EOF'
cd "$1" || exit 1
# build output look-alike, using real derivations from the store
find /nix/store -maxdepth 1 -name '*.drv' 2>/dev/null | shuf -n 8 | while IFS= read -r d; do
    b="${d##*/}"
    n="${b:33}"
    print -P "%F{green}${n%.drv}> building '${d}'%f"
done
print -r -- "$(starship prompt) gi"
onefetch --number-of-file-churns 0 --no-color-palette
print -r -- "$(starship prompt) gl"
git log --color=always --oneline --decorate --graph | head -n 12
exec zsh -i
EOF

    open_app code --new-window "$REPO_DIR"
    local code=$LAST_ADDR
    # undo the floating/center windowrule so it tiles like in the screenshot
    hyprctl dispatch "hl.dsp.window.float({ action = 'off', window = 'address:$code' })" >/dev/null
    code --reuse-window "$REPO_DIR/$VSCODE_FILE" >/dev/null 2>&1 || true
    sleep 5

    open_app "$TERM_BIN" -e zsh "$STAGE_DIR/term-info.zsh" "$REPO_DIR"
    local term=$LAST_ADDR
    sleep 4

    focus_window "$term"
    park_cursor
    capture 2.png "$term"

    close_window "$term"
    close_window "$code"
}

# ---------------------------------------------------------------- shot 3 ---
# 5 terminals: fastfetch | cmatrix / tty-clock | cbonsai / btop
shot3() {
    echo "== shot 3: terminals =="
    ensure_ws
    set_wallpaper japanese_pedestrian_street.png

    printf 'fastfetch\nexec zsh -i\n' >"$STAGE_DIR/term-fetch.zsh"

    open_app "$TERM_BIN" -e zsh "$STAGE_DIR/term-fetch.zsh"
    local ff=$LAST_ADDR
    sleep 1

    # dwindle: new windows split right/bottom of the focused one
    open_app "$TERM_BIN" -e cmatrix -C yellow
    local cm=$LAST_ADDR

    focus_window "$ff"
    open_app "$TERM_BIN" -e tty-clock -c -C 3
    local tc=$LAST_ADDR

    focus_window "$cm"
    open_app "$TERM_BIN" -e btop
    local bt=$LAST_ADDR

    # spawn cbonsai last so it renders at its final window size
    focus_window "$tc"
    open_app "$TERM_BIN" --wait-after-command=true -e cbonsai -p -M 10 -L 45
    local cb=$LAST_ADDR

    sleep 3
    focus_window "$bt"
    park_cursor
    capture 3.png "$bt"

    for addr in "$ff" "$cm" "$tc" "$bt" "$cb"; do
        hclose "$addr"
    done
    sleep 0.4
}

shot1
shot2
shot3

hws "$ORIG_WS" >/dev/null
echo "done - screenshots updated in $OUT_DIR"
notify-send -a "Screenshots" "Updated 1.png, 2.png and 3.png" || true
