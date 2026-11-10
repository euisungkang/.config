#!/usr/bin/env bash
# Unified Ctrl+hjkl navigation between Hyprland windows and Neovim splits.
#
# If the focused window has a running Neovim inside it, forward the keypress to
# Neovim over its server socket (Neovim then decides whether to move between its
# own splits or fall through to Hyprland at the edge). Otherwise move Hyprland
# focus directly. Talking to the nvim socket avoids re-injecting a key that
# Hyprland would just grab again, so there is no feedback loop.
#
# Usage: nvim-nav.sh <hypr-dir> <nvim-key>
#   nvim-nav.sh l h   # Ctrl+h -> left
#   nvim-nav.sh r l   # Ctrl+l -> right
#   nvim-nav.sh d j   # Ctrl+j -> down
#   nvim-nav.sh u k   # Ctrl+k -> up
set -u

dir="$1" # l | r | u | d  (hyprctl movefocus)
key="$2" # h | l | j | k  (nvim <C-key>)

pid=$(hyprctl activewindow -j | jq -r '.pid // empty')

if [ -n "$pid" ]; then
	# A TUI Neovim is two processes (nvim -> nvim --embed); the server socket
	# belongs to the --embed child, so scan every nvim in the focused window's
	# process tree and use the first one that has a live socket.
	runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
	for nvim_pid in $(pstree -p "$pid" 2>/dev/null | grep -oP '\bnvim\(\K[0-9]+'); do
		sock="${runtime}/nvim.${nvim_pid}.0"
		if [ -S "$sock" ]; then
			nvim --server "$sock" --remote-send "<C-${key}>" && exit 0
		fi
	done
fi

hyprctl dispatch movefocus "$dir"
