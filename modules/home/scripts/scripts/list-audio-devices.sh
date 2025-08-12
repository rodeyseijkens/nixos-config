#!/usr/bin/env bash

# List audio sinks (output devices)
echo "[ OUTPUT DEVICES]"
pactl list sinks short | while read -r line; do
    sink_id=$(echo "$line" | cut -f1)
    sink_name=$(echo "$line" | cut -f2)
    echo "$sink_id - ($sink_name)"
done

echo ""

# List audio sources (input devices)
echo "[ INPUT DEVICES]"
pactl list sources short | while read -r line; do
    source_id=$(echo "$line" | cut -f1)
    source_name=$(echo "$line" | cut -f2)
    echo "$source_id - ($source_name)"
done

echo ""

# List audio cards
echo "[󰲸 AUDIO CARDS]"
pactl list cards | awk '
BEGIN {
    profiles_count = 0
    current_profiles = ""
    alsa_name = ""
}
/^Card #/ {
    card_id = $2
    gsub(/#/, "", card_id)
    # Print previous card profiles if any
    if (current_profiles != "") {
        print_profiles_with_last_indicator()
        print ""
    }
    profiles_count = 0
    current_profiles = ""
    alsa_name = ""
}
/Name: / {
    card_name_id = $2
}
/alsa\.card_name = / {
    # Extract everything after "alsa.card_name = " and remove quotes
    alsa_line = $0
    sub(/.*alsa\.card_name = /, "", alsa_line)
    gsub(/^"/, "", alsa_line)
    gsub(/"$/, "", alsa_line)
    alsa_name = alsa_line
    printf "%s\n%s ┬ ( %s )\n", alsa_name, card_id, card_name_id
}
/Profiles:/ {
    print_profiles = 1
    next
}
/Active Profile:/ {
    print_profiles = 0
}
print_profiles && /^\t/ {
    profile_line = $0
    gsub(/^\t/, "", profile_line)
    if (profile_line != "" && profile_line !~ /^$/) {
        # Extract the profile name (everything before the first space and description)
        split(profile_line, parts, " ")
        profile_name = parts[1]
        # Remove trailing colon
        gsub(/:$/, "", profile_name)
        if (profile_name != "" && profile_name !~ /^$/) {
            profiles_count++
            if (current_profiles == "") {
                current_profiles = profile_name
            } else {
                current_profiles = current_profiles "\n" profile_name
            }
        }
    }
}
END {
    # Print the last card profiles
    if (current_profiles != "") {
        print_profiles_with_last_indicator()
    }
}
function print_profiles_with_last_indicator() {
    split(current_profiles, profile_array, "\n")
    for (i = 1; i <= profiles_count; i++) {
        if (i == profiles_count) {
            printf "   └─ %s\n", profile_array[i]
        } else {
            printf "   ├─ %s\n", profile_array[i]
        }
    }
}
'