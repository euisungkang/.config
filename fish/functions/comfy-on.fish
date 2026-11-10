function comfy-on --description 'Start ComfyUI at http://127.0.0.1:8188'
    if ss -ltn | string match -q -- '*127.0.0.1:8188*'
        echo "ComfyUI is already running at http://127.0.0.1:8188"
        return 0
    end
    /home/easton/ComfyUI/start.sh >/tmp/comfyui.log 2>&1 &
    disown $last_pid
    echo "Starting ComfyUI. Open http://127.0.0.1:8188"
    echo "Log: /tmp/comfyui.log"
end
