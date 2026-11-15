#!/usr/bin/env bash
#
# Compares the calendar sync's output against a recorded golden document.
#
#   tests/calendar-sync/run.sh [path/to/shell-calendar-sync]
#
# The sync is pointed at tests/calendar-sync/fake-caldir, which answers from
# the JSON files in data/, so nothing here reads a real calendar or the
# network. Only syncedAt is ignored, because it is the run's own clock.
#
# A change in behaviour is meant to fail this test: update expected.json in
# the same commit only after deciding the new output is right.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ENTRY="${1:-$ROOT/modules/home/quickshell/config/plugins/panels/calendar/sync/shell-calendar-sync}"

if [ -z "${CALENDAR_SYNC_TEST_SHELL:-}" ]; then
    exec nix shell nixpkgs#jq nixpkgs#gawk nixpkgs#gnugrep nixpkgs#gnused nixpkgs#coreutils \
        --command env CALENDAR_SYNC_TEST_SHELL=1 bash "$0" "$@"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

jq --arg bin "$HERE/fake-caldir" '. + {caldirPath: $bin}' "$HERE/config.json" >"$WORK/config.json"

# A named zone, so the rows do not follow whatever offset the machine has.
TZ=Europe/Amsterdam "$ENTRY" --config "$WORK/config.json" --out "$WORK/out.json"

jq -S 'del(.syncedAt)' "$WORK/out.json" >"$WORK/got.json"
jq -S 'del(.syncedAt)' "$HERE/expected.json" >"$WORK/want.json"

if ! diff -u "$WORK/want.json" "$WORK/got.json"; then
    echo "FAIL: the sync output no longer matches tests/calendar-sync/expected.json" >&2
    exit 1
fi

echo "PASS: $(jq '.events | length' "$WORK/got.json") rows match the golden document"
