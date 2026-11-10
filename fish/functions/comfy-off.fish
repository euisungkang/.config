function comfy-off --description 'Stop ComfyUI'
    # start.sh execs a relative .venv/bin/python, so match the listener comfy-on checks.
    set -l pids (ss -ltnp 'sport = :8188' | string match -rg 'pid=(\d+)')
    if test -z "$pids"
        echo "ComfyUI is not running"
        return 0
    end
    kill $pids
    echo "Stopped ComfyUI"
end
