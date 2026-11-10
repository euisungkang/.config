#!/bin/sh
# Fully quit the focused app (like macOS Cmd+Q).
win=$(hyprctl activewindow -j)
pid=$(echo "$win" | jq -r '.pid // empty')
class=$(echo "$win" | jq -r '.class // empty')
[ -z "$pid" ] && exit 0

# Steam's window belongs to a helper that Steam respawns; ask Steam itself to exit
if [ "$class" = "steam" ]; then
    exec steam -shutdown
fi

kill "$pid"
sleep 1
kill -9 "$pid" 2>/dev/null
