#!/usr/bin/env bash
# Open a fullscreen Haruna window on the focused display (or on every connected display with "all"), each with every video in CORSAIR/nice/k as its own shuffled playlist.
# Skips macOS "._*" AppleDouble stubs, which have video extensions but are not videos.

dir="/run/media/$USER/CORSAIR/nice/k"
cache="${XDG_CACHE_HOME:-$HOME/.cache}"

if [[ ! -d $dir ]]; then
    # Drive may be plugged in but not mounted; mount it via udisks (no root needed)
    dev=$(blkid -L CORSAIR 2>/dev/null)
    [[ -n $dev ]] && udisksctl mount -b "$dev" >/dev/null 2>&1
fi

if [[ ! -d $dir ]]; then
    notify-send -a Haruna "CORSAIR not mounted" "Can't find $dir"
    exit 1
fi

videos=$(find "$dir" -maxdepth 1 -type f ! -name '._*' -iregex '.*\.\(mp4\|mkv\|webm\|mov\|avi\|m4v\|wmv\|flv\|ts\)')

if [[ -z $videos ]]; then
    notify-send -a Haruna "No videos found" "$dir"
    exit 1
fi

haruna_addrs() { hyprctl clients -j | jq -r '.[] | select(.class | test("haruna"; "i")) | .address' | sort; }

orig_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

while read -r mon; do
    playlist="$cache/haruna-k-$mon.m3u"
    { echo "#EXTM3U"; shuf <<< "$videos"; } > "$playlist"

    before=$(haruna_addrs)
    hyprctl dispatch focusmonitor "$mon" >/dev/null
    # Haruna restores LastPlayedFile (RememberState) over the playlist, so drop it to start on the shuffled first entry
    sed -i "/^LastPlayedFile=/d" "${XDG_CONFIG_HOME:-$HOME/.config}/haruna/haruna.conf"
    app2unit -- haruna "$playlist" &

    # Wait for the new window to map, then fullscreen it
    for _ in {1..50}; do
        new=$(comm -13 <(echo "$before") <(haruna_addrs) | head -n1)
        [[ -n $new ]] && break
        sleep 0.2
    done
    if [[ -n $new ]]; then
        hyprctl dispatch focuswindow "address:$new" >/dev/null
        hyprctl dispatch fullscreen 0 >/dev/null
    fi
done < <(if [[ $1 == all ]]; then hyprctl monitors -j | jq -r '.[].name'; else echo "$orig_monitor"; fi)

[[ -n $orig_monitor ]] && hyprctl dispatch focusmonitor "$orig_monitor" >/dev/null
