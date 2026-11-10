if status is-interactive
    # Starship custom prompt
    starship init fish | source

    # Direnv + Zoxide
    command -v direnv &>/dev/null && direnv hook fish | source
    command -v zoxide &>/dev/null && zoxide init fish --cmd cd | source

    # Better ls
    alias ls='eza --icons --group-directories-first -1'

    alias gh='cd ~/Desktop/github'
    alias gh-auth='command gh auth login'
    alias work='cd ~/Desktop/work'
    # alias claude='claude --model claude-opus-4-6'
    function claude-config --description 'Claude session in ~/.config (Sonnet, medium effort, auto mode)'
        env --chdir=$HOME/.config claude --model sonnet --effort medium --permission-mode auto $argv
    end
    function grok-config --description 'Grok session in ~/.config (grok-4.7, medium effort, always-approve)'
        grok --cwd $HOME/.config --model grok-4.7 --reasoning-effort medium --always-approve $argv
    end
    alias vim='nvim'
    alias source-fish='source ~/.config/fish/config.fish'
    alias conductor='ssh conductor'
    alias fafnir='ssh fafnir'

    # Abbrs
    abbr lg lazygit
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    abbr l ls
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'

    # Custom colours
    cat ~/.local/state/caelestia/sequences.txt 2>/dev/null

    # For jumping between prompts in foot terminal
    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end

    # Custom fish config
    source ~/.config/caelestia/user-config.fish 2>/dev/null
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /home/easton/miniforge3/bin/conda
    eval /home/easton/miniforge3/bin/conda "shell.fish" hook $argv | source
else
    if test -f "/home/easton/miniforge3/etc/fish/conf.d/conda.fish"
        . "/home/easton/miniforge3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH /home/easton/miniforge3/bin $PATH
    end
end
# <<< conda initialize <<<

# Secrets live in an untracked file (see .gitignore)
test -f ~/.config/fish/secrets.fish; and source ~/.config/fish/secrets.fish

# >>> grok installer >>>
fish_add_path $HOME/.grok/bin
# <<< grok installer <<<

# Env beats config.toml for session-trace upload. Pin it off for every fish session.
set -gx GROK_TELEMETRY_TRACE_UPLOAD false
