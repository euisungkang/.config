#!/usr/bin/env bash
# Per-monitor night light via wlsunset (one instance per output).
#   nightlight-toggle.sh start   launch scheduled instances (exec-once)
#   nightlight-toggle.sh         toggle night light on the focused monitor
# Schedule: warm from 20:00 to 07:00. A toggle that disagrees with the
# schedule forces the state on that monitor; toggling back returns to auto.
# wlsunset cycles auto -> high (off) -> low (on) -> auto on SIGUSR1, so the
# current mode is tracked in a state file per output.

temp=3500
dir="${XDG_RUNTIME_DIR:-/tmp}/nightlight"
mkdir -p "$dir"

start_instance() {
    echo auto > "$dir/$1"
    wlsunset -o "$1" -S 07:00 -s 20:00 -d 1 -t "$temp" -T 6500 &
}

if [[ "$1" == start ]]; then
    # Old instances must release gamma control first, or Hyprland rejects the
    # new request and leaks a stale controller that blocks the output for good
    pkill -x wlsunset
    while pgrep -x wlsunset > /dev/null; do sleep 0.1; done
    sleep 0.2
    for out in $(hyprctl monitors all -j | jq -r '.[].name'); do
        start_instance "$out"
    done
    wait
    exit
fi

out=$(hyprctl monitors -j | jq -r '.[] | select(.focused).name')
pid=$(pgrep -fo "^wlsunset -o $out ")
if [[ -z "$pid" ]]; then
    start_instance "$out" > /dev/null 2>&1 &
    disown
    sleep 0.3
    pid=$(pgrep -fo "^wlsunset -o $out ")
fi

mode=$(cat "$dir/$out" 2>/dev/null || echo auto)
hhmm=$((10#$(date +%H%M)))
(( hhmm >= 2000 || hhmm < 700 )) && auto_warm=on || auto_warm=off
[[ $mode == auto ]] && current=$auto_warm || current=$mode
[[ $current == on ]] && target=off || target=on
[[ $target == "$auto_warm" ]] && new=auto || new=$target

# Signals needed to move between modes in the order auto -> off -> on -> auto
order=(auto off on)
idx() { for i in 0 1 2; do [[ ${order[i]} == "$1" ]] && echo "$i"; done; }
n=$(( ($(idx "$new") - $(idx "$mode") + 3) % 3 ))
for ((i = 0; i < n; i++)); do kill -USR1 "$pid"; sleep 0.05; done
echo "$new" > "$dir/$out"

if [[ $target == on ]]; then
    notify-send -i weather-clear-night-symbolic "Night light on" "$out · ${temp}K" -a "Hyprland"
else
    notify-send -i weather-clear-symbolic "Night light off" "$out" -a "Hyprland"
fi
