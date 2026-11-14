#!/usr/bin/env bash
#
# Screenshot and colour check for the Aarambh QEMU harness.
#
#   screen.sh dump <monitor-socket> <out.ppm>   ask QEMU for a screenshot
#   screen.sh check <image>                     check the Gruvbox theme colours
#
# check exits 0 when the paper colour fills a large part of the screen and the
# accent colour shows up, which is how the editorial-gruvbox theme looks. The
# Editorial Dark theme (#15130f paper) fails the check.

set -euo pipefail

# base01 (paper) and base0D (accent), as RGB.
PAPER=(60 56 54)
ACCENT=(152 151 26)
TOLERANCE=12
# Every third pixel in each direction, a third of the screen.
SAMPLE_PERCENT=33.334
PAPER_MIN_PERCENT=20
ACCENT_MIN_PIXELS=20

dump() {
    local socket=$1 out=$2
    # QEMU writes the file named here. The monitor reads paths in its own
    # working directory, so the harness passes absolute paths. nc sends the
    # command, then waits until QEMU closes the socket or goes quiet for 5 s.
    printf 'screendump %s\n' "$out" | nc -U -w 5 "$socket" >/dev/null
}

check() {
    local image=$1 stats paper total accent share
    # ImageMagick samples the screen and prints each colour with its count. awk
    # adds up the counts that fall within TOLERANCE of each target colour on
    # every channel, which is the same rule the Python check used.
    stats=$(
        magick "$image" -depth 8 -sample "${SAMPLE_PERCENT}%" -format %c histogram:info:- |
            awk -v tol="$TOLERANCE" \
                -v pr="${PAPER[0]}" -v pg="${PAPER[1]}" -v pb="${PAPER[2]}" \
                -v ar="${ACCENT[0]}" -v ag="${ACCENT[1]}" -v ab="${ACCENT[2]}" '
            function gap(a, b) { return a > b ? a - b : b - a }
            function near(r, g, b, tr, tg, tb) {
                return gap(r, tr) <= tol && gap(g, tg) <= tol && gap(b, tb) <= tol
            }
            {
                count = $1
                sub(/:$/, "", count)
                split(substr($2, 2, length($2) - 2), rgb, ",")
                total += count
                if (near(rgb[1], rgb[2], rgb[3], pr, pg, pb)) {
                    paper += count
                } else if (near(rgb[1], rgb[2], rgb[3], ar, ag, ab)) {
                    accent += count
                }
            }
            END { print paper + 0, total + 0, accent + 0 }'
    )
    read -r paper total accent <<<"$stats"

    if [ "$total" -eq 0 ]; then
        echo "no pixels in $image" >&2
        return 1
    fi
    share=$(awk -v p="$paper" -v t="$total" 'BEGIN { printf "%.1f", 100 * p / t }')
    echo "paper ${share}% of the screen, accent pixels $accent"

    if [ $((paper * 100)) -ge $((total * PAPER_MIN_PERCENT)) ] && [ "$accent" -ge "$ACCENT_MIN_PIXELS" ]; then
        echo "theme: editorial-gruvbox colours found"
        return 0
    fi
    echo "theme: editorial-gruvbox colours NOT found"
    return 1
}

usage() {
    sed -n '3,8p' "$0" >&2
    return 2
}

main() {
    case "${1:-}" in
    dump)
        [ "$#" -eq 3 ] || usage
        dump "$2" "$3"
        ;;
    check)
        [ "$#" -eq 2 ] || usage
        check "$2"
        ;;
    *)
        usage
        ;;
    esac
}

main "$@"
