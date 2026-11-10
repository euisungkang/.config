function comfy-open --description 'Open the ComfyUI output folder'
    xdg-open /home/easton/ComfyUI/output >/dev/null 2>&1 &
    disown
end
