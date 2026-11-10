function llm-stop --description 'Unload all running Ollama models'
    for m in (ollama ps | tail -n +2 | awk '{print $1}')
        ollama stop $m
    end
    ollama ps
end
