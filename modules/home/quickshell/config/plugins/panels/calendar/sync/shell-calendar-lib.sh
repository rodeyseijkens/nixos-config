#!/usr/bin/env bash
# shellcheck disable=SC2034  # the callers that source this file read these variables
#
# Shared shell helpers for the calendar sync and the event command.
#
# Sourced, never run. Needs $CALDIR_PATH set by the caller. Functions that can
# fail return 1 and put a message for a person in $CALDIR_ERR; they never exit,
# because the two callers report failures differently (a log line and a JSON
# reply).

CALDIR_ERR=""

# ---- Time ------------------------------------------------------------------

# The local IANA zone name, or "" when none can be named. A named zone is what
# keeps an event on the far side of a daylight saving change on its own day.
zoneinfo_root() {
    local target
    target=$(readlink -f /etc/localtime 2>/dev/null || true)
    case "$target" in
    *zoneinfo/*) printf '%s' "${target%%/zoneinfo/*}/zoneinfo" ; return 0 ;;
    esac
    if [ -d /usr/share/zoneinfo ]; then
        printf '%s' /usr/share/zoneinfo
        return 0
    fi
    return 1
}

resolve_local_timezone() {
    local root name target
    root=$(zoneinfo_root || true)

    if [ -n "${TZ:-}" ]; then
        name=${TZ#:}
        if [ -n "$root" ] && [ -f "$root/$name" ]; then
            printf '%s' "$name"
            return 0
        fi
    fi

    target=$(readlink -f /etc/localtime 2>/dev/null || true)
    case "$target" in
    *zoneinfo/*)
        name=${target#*zoneinfo/}
        if [ -n "$name" ]; then
            printf '%s' "$name"
            return 0
        fi
        ;;
    esac

    echo "warning: could not determine the named timezone; using a fixed offset instead. Events spanning a daylight saving transition may be off by a day." >&2
    printf '%s' ""
}

local_offset_seconds() {
    local sign hh mm offset
    sign=$(date +%z)
    hh=${sign:1:2}
    mm=${sign:3:2}
    offset=$(( 10#$hh * 3600 + 10#$mm * 60 ))
    if [ "${sign:0:1}" = "-" ]; then
        offset=$(( -offset ))
    fi
    printf '%d' "$offset"
}

# Call after CALDIR_LOCAL_ZONE / CALDIR_FIXED_OFFSET are set by start_clock.
start_clock() {
    CALDIR_LOCAL_ZONE=$(resolve_local_timezone)
    if [ -n "$CALDIR_LOCAL_ZONE" ]; then
        export TZ="$CALDIR_LOCAL_ZONE"
        CALDIR_FIXED_OFFSET=""
    else
        CALDIR_FIXED_OFFSET=$(local_offset_seconds)
    fi
}

# A local ISO string for an epoch, in the same shape Python's isoformat gives.
local_iso() {
    local epoch=$1 frac=${2:-}
    if [ -n "$CALDIR_LOCAL_ZONE" ]; then
        printf '%s' "$(date -d "@$epoch" +%Y-%m-%dT%H:%M:%S)${frac}$(date -d "@$epoch" +%:z)"
    else
        date -u -d "@$((epoch + CALDIR_FIXED_OFFSET))" +%Y-%m-%dT%H:%M:%S | {
            read -r base
            local sign="+" off=$CALDIR_FIXED_OFFSET
            if [ "$off" -lt 0 ]; then sign="-" ; off=$(( -off )) ; fi
            printf '%s%s%s%02d:%02d' "$base" "$frac" "$sign" $((off / 3600)) $(( (off % 3600) / 60 ))
        }
    fi
}

# A local wall clock as "HH:MM:SS" for an epoch.
local_hms() {
    if [ -n "$CALDIR_LOCAL_ZONE" ]; then
        date -d "@$1" +%H:%M:%S
    else
        date -u -d "@$(($1 + CALDIR_FIXED_OFFSET))" +%H:%M:%S
    fi
}

# The local date of an epoch.
local_date() {
    if [ -n "$CALDIR_LOCAL_ZONE" ]; then
        date -d "@$1" +%Y-%m-%d
    else
        date -u -d "@$(($1 + CALDIR_FIXED_OFFSET))" +%Y-%m-%d
    fi
}

# The local midnight of a date, as an epoch.
midnight_epoch() {
    if [ -n "$CALDIR_LOCAL_ZONE" ]; then
        date -d "$1 00:00:00" +%s
    else
        printf '%d' $(( $(date -u -d "$1 00:00:00" +%s) - CALDIR_FIXED_OFFSET ))
    fi
}

add_days_epoch_ymd() {
    date -d "$1 $2 day" +%Y-%m-%d
}

# Epoch of an RFC3339 value. A value without an offset is refused.
parse_instant() {
    local value=$1
    if ! [[ "$value" =~ (Z|[+-][0-9]{2}:?[0-9]{2})$ ]]; then
        return 1
    fi
    date -d "$value" +%s 2>/dev/null
}

# ".123456" for a value that carries a fraction, else "".
fraction_of() {
    if [[ "$1" =~ \.([0-9]+) ]]; then
        printf '.%s' "$(printf '%-6s' "${BASH_REMATCH[1]:0:6}" | tr ' ' '0')"
    fi
}

# A datetime with its wall clock kept and its offset spelled the way Python's
# isoformat spells it, e.g. "+0100" and "Z" become "+01:00".
normalise_datetime() {
    local raw=$1 offset suffix
    if [[ "$raw" =~ (Z|[+-][0-9]{2}:?[0-9]{2})$ ]]; then
        offset=${BASH_REMATCH[1]}
    else
        return 1
    fi
    suffix=$offset
    if [ "$offset" = "Z" ]; then
        suffix="+00:00"
    elif [[ "$offset" =~ ^([+-][0-9]{2})([0-9]{2})$ ]]; then
        suffix="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
    fi
    printf '%s%s' "${raw%"$offset"}" "$suffix"
}

# A Google start/end node as JSON: a date for an all-day event, else a
# dateTime with an offset. "" means unusable.
node_of() {
    local raw=$1 all_day=$2
    [ -n "$raw" ] || return 0
    if [ "$all_day" = "true" ]; then
        jq -cn --arg d "${raw:0:10}" '{date: $d}'
        return 0
    fi
    local normalised
    normalised=$(normalise_datetime "$raw") || return 1
    jq -cn --arg dt "$normalised" '{dateTime: $dt}'
}

# ---- caldir ----------------------------------------------------------------

run_caldir() {
    "$CALDIR_PATH" "$@"
}

# JSON from one caldir command. On failure, $CALDIR_ERR says why.
caldir_json() {
    local out err
    err=$(mktemp)
    if ! out=$(run_caldir --json "$@" 2>"$err"); then
        local excerpt
        excerpt=$(head -c 400 "$err" | tr '\n' ' ' | cut -c1-200)
        rm -f "$err"
        CALDIR_ERR="caldir ${1} failed: ${excerpt:-no stderr output}"
        return 1
    fi
    rm -f "$err"
    if ! jq -e . >/dev/null 2>&1 <<<"$out"; then
        CALDIR_ERR="caldir ${1} returned invalid JSON"
        return 1
    fi
    printf '%s' "$out"
}

caldir_version() {
    local stdout
    if ! stdout=$("$CALDIR_PATH" --version 2>/dev/null); then
        CALDIR_ERR="cannot read the caldir version"
        return 1
    fi
    if [[ "$stdout" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        printf '%s.%s.%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    else
        CALDIR_ERR="cannot parse caldir version from '$stdout'"
        return 1
    fi
}

default_calendar() {
    local payload
    if ! payload=$("$CALDIR_PATH" --json config 2>/dev/null); then
        printf '%s' ""
        return 0
    fi
    jq -r '.config.default_calendar // "" | tostring' <<<"$payload" 2>/dev/null || printf '%s' ""
}

# ---- Event resources -------------------------------------------------------

PARTSTAT='{"ACCEPTED":"accepted","DECLINED":"declined","TENTATIVE":"tentative","NEEDSACTION":"needsAction"}'

partstat_google() {
    local upper
    upper=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -d '-')
    jq -r --arg k "$upper" '.[$k] // ""' <<<"$PARTSTAT"
}

# One caldir event as the intermediate record both callers use. Time fields
# stay raw here; they become nodes per event.
raw_record() {
    jq -c '
        def text: tostring;
        (.x_properties // []) as $props
        | ([ $props[] | select((.name // "" | ascii_upcase) == "X-GOOGLE-CONFERENCE") | .value // "" ] | first) as $conferenceProp
        | ([ $props[] | select((.name // "" | ascii_upcase) == "X-GOOGLE-EVENT-TYPE") | .value // "" ] | first // "") as $kind
        | {
            uid: (if ((.uid // "") | text) != "" then (.uid | text) else (.instance_id // "" | text) end),
            title: (if ((.title // "") | text) != "" then (.title | text) else (.summary // "" | text) end),
            location: ((.location // "") | text),
            description: ((.description // "") | text),
            status: ((.status // "") | text | ascii_downcase),
            rsvp: ((.rsvp // "") | text),
            allDay: (.all_day == true),
            startRaw: (if .start == null then "" else (.start | text) end),
            endRaw: (if .end == null then "" else (.end | text) end),
            conference: (if $conferenceProp != null then ($conferenceProp | text) else (.url // "" | text) end),
            eventType: $kind,
            reminders: ([ (.reminders // [])[]
                          | .minutes_before_start
                          | select(type == "number" and . >= 0 and . == floor) ]
                        | unique | sort)
          }
    '
}

# The event's start and end nodes as JSON, or "" when a value is unusable.
# echo start<TAB>end
nodes_of_record() {
    local record=$1 all_day start_raw end_raw start_node end_node
    all_day=$(jq -r '.allDay' <<<"$record")
    start_raw=$(jq -r '.startRaw' <<<"$record")
    end_raw=$(jq -r '.endRaw' <<<"$record")
    [ -n "$start_raw" ] || return 1
    if [ "$all_day" = "true" ]; then
        start_raw=${start_raw:0:10}
        [ -n "$end_raw" ] || end_raw=$start_raw
        end_raw=${end_raw:0:10}
    fi
    start_node=$(node_of "$start_raw" "$all_day") || return 1
    end_node=$(node_of "$end_raw" "$all_day") || return 1
    [ -n "$end_node" ] || end_node=$start_node
    printf '%s\t%s' "$start_node" "$end_node"
}
