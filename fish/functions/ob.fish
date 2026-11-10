function ob --description "Open path in Obsidian (no args: ./.jikimi/vault, created and registered if missing)"
    set -l target
    if test (count $argv) -gt 0
        set target (realpath $argv[1])
    else
        set target $PWD/.jikimi/vault
        mkdir -p $target
        # Obsidian only opens registered vaults, so add new ones to its config
        set -l cfg (set -q OBSIDIAN_CONFIG; and echo $OBSIDIAN_CONFIG; or echo ~/.config/obsidian/obsidian.json)
        if test -f $cfg; and not jq -e --arg p $target '.vaults | any(.[]; .path == $p)' $cfg >/dev/null
            set -l id (head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')
            set -l ts (math (date +%s) x 1000)
            jq -c --arg id $id --arg p $target --argjson ts $ts \
                '.vaults[$id] = {path: $p, ts: $ts}' $cfg >$cfg.tmp; and mv $cfg.tmp $cfg
        end
    end
    xdg-open "obsidian://open?path=$target" >/dev/null 2>&1 &
    disown
end
