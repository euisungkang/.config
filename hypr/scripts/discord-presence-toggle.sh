#!/usr/bin/env bash
# Toggle the custom Discord Rich Presence (discord-presence systemd user service).
# Stopping the service closes its IPC connection, which clears the presence in Discord.
if systemctl --user is-active --quiet discord-presence.service; then
	systemctl --user stop discord-presence.service
	notify-send -a "Discord Presence" -i discord "Discord presence off"
else
	systemctl --user start discord-presence.service
	notify-send -a "Discord Presence" -i discord "Discord presence on"
fi
