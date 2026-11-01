#!/usr/bin/env bash

WALL_DIR="$HOME/.local/share/wallpapers"

wallpaper=$(find -L "$WALL_DIR" -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) \
  | shuf -n 1)

if [ -z "$wallpaper" ]; then
  echo "Nenhum wallpaper encontrado em $WALL_DIR"
  exit 1
fi

dms ipc call wallpaper set "$wallpaper"

# A static wallpaper replaces an active video wallpaper.
if command -v ryoku-video-wallpaper >/dev/null 2>&1; then
  ryoku-video-wallpaper stop
fi
