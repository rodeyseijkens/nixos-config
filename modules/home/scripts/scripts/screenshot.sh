#!/usr/bin/env bash

dir="$HOME/Pictures/Screenshots"
time=$(date +'%Y_%m_%d_at_%Hh%Mm%Ss')
file="${dir}/Screenshot_${time}.png"

copy() {
    grimblast --notify --freeze copy area
}

save() {
    grimblast --notify --freeze save area "$file"
}

satty_() {
   grimblast --notify --freeze save area "$file"
   satty -f "$file"
}

if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
fi

if [[ "$1" == "--copy" ]]; then
    copy
elif [[ "$1" == "--save" ]]; then
    save
elif [[ "$1" == "--satty" ]]; then
    satty_
else
    echo -e "Available Options: --copy --save --satty"
fi

exit 0
