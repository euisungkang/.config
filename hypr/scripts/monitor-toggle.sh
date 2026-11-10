#!/usr/bin/env bash
# Toggle a Hyprland monitor on/off at runtime.
# Usage: monitor-toggle.sh <NAME>   (defaults to DP-2)
#
# Disabling drops the output and reflows its workspaces onto the remaining
# monitor(s). Re-enabling reuses the line from monitors.conf so it matches
# the persistent config (resolution/refresh/position/scale).

set -euo pipefail

mon="${1:-DP-2}"
conf="$HOME/.config/hypr/monitors.conf"

disabled=$(hyprctl -j monitors all | jq -r --arg m "$mon" \
    '.[] | select(.name == $m) | .disabled')

if [[ -z "$disabled" ]]; then
    notify-send -u critical -i video-display-symbolic "Monitor toggle" "Unknown monitor: $mon" -a "Hyprland"
    exit 1
fi

if [[ "$disabled" == "false" ]]; then
    hyprctl keyword monitor "$mon, disable"
    notify-send -i video-display-symbolic "Monitor disabled" "$mon" -a "Hyprland"
else
    line=$(grep "^monitor=$mon," "$conf" | head -1)
    if [[ -z "$line" ]]; then
        notify-send -u critical -i video-display-symbolic "Monitor toggle" "No entry for $mon in monitors.conf" -a "Hyprland"
        exit 1
    fi
    hyprctl keyword monitor "${line#monitor=}"
    notify-send -i video-display-symbolic "Monitor enabled" "$mon" -a "Hyprland"
fi
