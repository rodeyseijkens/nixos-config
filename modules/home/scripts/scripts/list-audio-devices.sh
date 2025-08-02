#!/usr/bin/env bash

# List audio cards
echo "[󰲸 audio cards]"
pactl list cards short | while read -r line; do
    card_id=$(echo "$line" | cut -f1)
    card_name=$(echo "$line" | cut -f2)
    echo "$card_id > $card_name"
done

echo ""

# List audio sinks (output devices)
echo "[ output devices]"
pactl list sinks short | while read -r line; do
    sink_id=$(echo "$line" | cut -f1)
    sink_name=$(echo "$line" | cut -f2)
    echo "$sink_id > $sink_name"
done

echo ""

# List audio sources (input devices)
echo "[ input devices]"
pactl list sources short | while read -r line; do
    source_id=$(echo "$line" | cut -f1)
    source_name=$(echo "$line" | cut -f2)
    echo "$source_id > $source_name"
done
