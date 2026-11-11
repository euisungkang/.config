#!/usr/bin/env bash
# Bootstrap this environment on a fresh EndeavourOS/Arch install.
#   git clone https://github.com/euisungkang/.config.git ~/.config && ~/.config/install.sh
# Idempotent. Needs sudo for pacman. Secrets are NOT in this repo: see "Manual steps".
set -euo pipefail
CFG="$HOME/.config"
CAE="$HOME/.local/share/caelestia"
PRIV="$HOME/.config-private"
cd "$CFG"

say() { printf '\n==> %s\n' "$*"; }

say "Packages"
sudo pacman -S --needed --noconfirm - < packages/pkglist-native.txt
if command -v yay >/dev/null; then yay -S --needed --noconfirm - < packages/pkglist-aur.txt
else echo "yay not found: install it, then: yay -S --needed - < packages/pkglist-aur.txt"; fi

say "Caelestia upstream (for unmodified parts: fastfetch, starship, spicetify, ...)"
[[ -d $CAE/.git ]] || git clone https://github.com/caelestia-dots/caelestia.git "$CAE"
# Customised dirs live in ~/.config; point the clone back at them so edits are tracked here.
for d in hypr fish foot btop uwsm; do
  [[ -L $CAE/$d && $(readlink -f "$CAE/$d") == "$CFG/$d" ]] && continue
  rm -rf "${CAE:?}/$d"; ln -s "$CFG/$d" "$CAE/$d"
done
# Untouched upstream dirs: link into ~/.config if absent.
for d in fastfetch spicetify starship.toml; do
  [[ -e $CFG/$d || -L $CFG/$d ]] || ln -s "$CAE/$d" "$CFG/$d"
done

say "Scripts and commit guard"
mkdir -p ~/.local/bin
ln -sfn "$CFG/bin/discord-presence" ~/.local/bin/discord-presence
git config core.hooksPath .githooks

say "Private repo (reminder units, gitconfig, ssh config, discord-presence config, wallpapers)"
if [[ -d $PRIV ]]; then
  mv -n "$CFG/systemd/user" "$CFG/systemd/user.pre" 2>/dev/null || true
  mkdir -p "$CFG/systemd" "$CFG/discord-presence" ~/.ssh
  ln -sfn "$PRIV/systemd/user" "$CFG/systemd/user"
  ln -sfn "$PRIV/discord-presence/config.json" "$CFG/discord-presence/config.json"
  ln -sfn "$PRIV/home/gitconfig" ~/.gitconfig
  ln -sfn "$PRIV/ssh/config" ~/.ssh/config
  mkdir -p ~/Pictures
  [[ -d ~/Pictures/Wallpapers && ! -L ~/Pictures/Wallpapers ]] && mv -n ~/Pictures/Wallpapers ~/Pictures/Wallpapers.pre
  ln -sfn "$PRIV/wallpapers" ~/Pictures/Wallpapers
  systemctl --user daemon-reload
  for t in "$PRIV"/systemd/user/*.timer; do systemctl --user enable --now "$(basename "$t")"; done
  systemctl --user enable --now discord-presence.service openrazer-daemon.service || true
else
  echo "~/.config-private not found: clone/copy it to $PRIV and re-run this script."
fi

say "Neovim plugins, tmux plugins"
nvim --headless "+Lazy! sync" +qa || true
[[ -x $CFG/tmux/plugins/tpm/bin/install_plugins ]] && "$CFG/tmux/plugins/tpm/bin/install_plugins" || true

cat <<'EOF'

==> Manual steps (deliberately not automated)
  Secrets/credentials - copy over a secure channel, never commit:
    ~/.ssh/*.pem, ~/.ssh/*.pub      ~/.config/fish/secrets.fish
    ~/.local/share/plaid-balance/   ~/.local/share/x-hub/   ~/.grok/   ~/.claude*/
    then: gh auth login ; bitwarden login
  Machine-specific (do NOT blindly copy from the desktop):
    hypr/monitors.conf, hypr/workspaces.conf, caelestia/monitors/*  -> regenerate with nwg-displays
    system/etc-environment (AQ_DRM_NO_EXPLICIT_SYNC is for the AMD desktop GPU)
    hypr/hyprland/input.conf (mouse accel/sensitivity), eno1-eee-off.service (desktop NIC)
  System services to review: system/enabled-system-units.txt ; system/ollama-override.conf
  Kotlin LSP for nvim (not in mason): https://github.com/Kotlin/kotlin-lsp/releases
    unpack to ~/.local/share/kotlin-lsp/<ver>/ and ln -s that dir -> ~/.local/share/kotlin-lsp/current
  T2 MacBook hardware support is separate (see the T2 wiki steps).
  Finish with: ~/.config/scripts/verify.sh
EOF
