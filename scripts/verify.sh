#!/usr/bin/env bash
# Verify the dotfiles layout and that nothing sensitive would be published.
# "Trackable" = what `git add -A` would stage (tracked + untracked-not-ignored).
set -u
cd "$HOME/.config" || exit 2
pass=0 fail=0
ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); echo "FAIL: $*"; }
check() { local msg=$1; shift; if "$@" >/dev/null 2>&1; then ok; else bad "$msg"; fi; }

trackable=$(git ls-files --cached --others --exclude-standard)
is_trackable() { grep -qxF -- "$1" <<<"$trackable"; }
is_ignored()   { git check-ignore -q --no-index -- "$1"; }
canon() { readlink -f -- "$1"; }

# 1. Real files live in ~/.config; the caelestia clone points back at them.
for d in hypr fish foot btop uwsm; do
  check "~/.config/$d must be a real directory" test -d "$d" -a ! -L "$d"
  check "~/.local/share/caelestia/$d must link to ~/.config/$d" \
    test "$(canon "$HOME/.local/share/caelestia/$d")" = "$HOME/.config/$d"
done

# 2. Things that must be trackable (public repo).
for f in hypr/hyprland/keybinds.conf hypr/scripts/nvim-nav.sh hypr/scripts/haruna-k.sh \
         hypr/monitors.conf fish/config.fish fish/functions/ob.fish fish/conf.d/paths.fish \
         foot/foot.ini btop/btop.conf uwsm/env-hyprland environment.d/kde-xdg.conf \
         mimeapps.list kdeglobals kglobalshortcutsrc fcitx5/profile qtengine/config.json \
         gtk-3.0/settings.ini packages/pkglist-native.txt packages/pkglist-aur.txt \
         bin/discord-presence system/etc-environment install.sh \
         scripts/verify.sh scripts/scan-secrets.sh .githooks/pre-commit; do
  is_trackable "$f" || bad "should be trackable: $f"
done

# 3. Things that must NOT be trackable.
for f in fish/secrets.fish fish/fish_variables fish/config.fish.bak.1 fish/functions/backup2.bak \
         hypr/scheme/current.conf systemd/user discord-presence/config.json \
         fcitx5/conf/cached_layouts btop/btop.log btop/themes/x.theme \
         quickshell/plaid-invest/__pycache__/x.pyc; do
  is_ignored "$f" || bad "should be ignored: $f"
done
for pat in '(^|/)secrets\.fish$' '\.pem$' 'credentials\.json$' '\.env$' 'fish_variables$'; do
  grep -Eq -- "$pat" <<<"$trackable" && bad "sensitive filename trackable: /$pat/"
done

# 4. Content scan of everything trackable (public repo).
# shellcheck disable=SC2046
if [[ -n $trackable ]]; then
  out=$(grep -v '^tmux/plugins/' <<<"$trackable" | xargs -d '\n' scripts/scan-secrets.sh 2>&1)
  [[ -z $out ]] && ok || bad "$out"
fi

# 5. Private repo owns personal data; public tree only sees symlinks into it.
P="$HOME/.config-private"
check "private repo exists" git -C "$P" rev-parse --git-dir
check "systemd/user must link into private repo" test "$(canon systemd/user)" = "$P/systemd/user"
check "discord-presence/config.json must link into private repo" \
  test "$(canon discord-presence/config.json)" = "$P/discord-presence/config.json"
check "private repo holds reminder units" compgen -G "$P/systemd/user/*.timer"
check "private repo ignores *.wants symlinks" git -C "$P" check-ignore -q --no-index systemd/user/timers.target.wants/x
check "private repo holds no ssh keys/pem" bash -c "! git -C '$P' ls-files --cached --others --exclude-standard | grep -Eq '\.pem$|\.pub$|id_'"
check "~/Pictures/Wallpapers must link into private repo" \
  test "$(canon "$HOME/Pictures/Wallpapers")" = "$P/wallpapers"
check "private repo tracks wallpapers" bash -c "git -C '$P' ls-files wallpapers | grep -Eiq '\.(png|jpe?g|webp)$'"
grep -Eiq '(^|/)wallpapers/' <<<"$trackable" && bad "wallpapers trackable in public repo" || ok

# 6. Commit guard installed.
check "core.hooksPath is .githooks" test "$(git config core.hooksPath)" = ".githooks"
check "pre-commit hook is executable" test -x .githooks/pre-commit

echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
