#!/bin/sh
set -eu

wallpaper=$(realpath -- "$1")

hyprctl -i 0 monitors | sed -n 's/^Monitor \([^ ]*\).*/\1/p' |
while IFS= read -r monitor; do
    hyprctl hyprpaper wallpaper "$monitor, $wallpaper, cover"
done

ln -sfn -- "$wallpaper" "$HOME/.current_wallpaper"
