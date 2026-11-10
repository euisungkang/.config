#!/bin/sh
# Open a new terminal in the focused foot window's shell cwd (falls back to $HOME).
dir="$HOME"
info=$(hyprctl activewindow -j)
if [ "$(echo "$info" | jq -r .class)" = "foot" ]; then
    pid=$(echo "$info" | jq -r .pid)
    shell=$(pgrep -P "$pid" | head -n1)
    [ -n "$shell" ] && d=$(readlink "/proc/$shell/cwd") && [ -d "$d" ] && dir="$d"
fi
exec app2unit -- foot --working-directory="$dir"
