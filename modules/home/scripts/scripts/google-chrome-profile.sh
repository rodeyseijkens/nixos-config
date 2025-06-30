#!/usr/bin/env bash

profile_name=$1; shift
local_state=~/.config/google-chrome/Local\ State
profile_key=`< "$local_state" jq -r '
    .profile.info_cache | to_entries | .[] |
    select(.value.name == "'"$profile_name"'") | .key'`
[ -n "$profile_key" ]
echo "Using profile: $profile_name ($profile_key)"
google-chrome-stable --profile-directory="$profile_key" "$@"