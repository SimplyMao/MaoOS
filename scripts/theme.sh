#!/bin/bash

# Directory containing wallpapers
WALLPAPER_DIR="$HOME/Wallpapers"

# Make sure directory exists
[ ! -d "$WALLPAPER_DIR" ] && {
  echo "Wallpaper directory not found!"
  exit 1
}

# Let user pick a wallpaper using Rofi
choice=$(ls "$WALLPAPER_DIR" | rofi -dmenu -p "Select Wallpaper")

# Exit if nothing selected
[ -z "$choice" ] && exit

# Full path to chosen image
img="$WALLPAPER_DIR/$choice"

# Set wallpaper using swww (smooth transition)
awww img "$img"

# Generate colors with Matugen
matugen image "$img" --source-color-index 0
