#!/bin/bash

hyprctl hyprpaper unload all
# Sets a random wallpaper with hyprpaper

# Use glob patterns directly to handle spaces in filenames
wallpapers=()
shopt -s nullglob  # Make globs expand to nothing if no matches

# Add wallpapers from home directory
for file in "$HOME"/.local/share/wallpapers/kurz/*.png; do
    wallpapers+=("$file")
done

# Add wallpapers from system directory  
for file in /usr/share/hypr/wall*; do
    wallpapers+=("$file")
done

shopt -u nullglob  # Reset nullglob

# Exit if no wallpapers found
if [ ${#wallpapers[@]} -eq 0 ]; then
    echo "No wallpapers found!"
    exit 1
fi

wall=${wallpapers[$RANDOM % ${#wallpapers[@]}]}

hyprctl hyprpaper preload "$wall"
hyprctl hyprpaper wallpaper ,"$wall"

