function claude-local
    curl -sf localhost:11434 >/dev/null; or begin; ollama serve >/dev/null 2>&1 & disown; sleep 2; end
    env ANTHROPIC_BASE_URL=http://localhost:11434 ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_API_KEY= \
        ENABLE_CLAUDEAI_MCP_SERVERS=false CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
        claude --strict-mcp-config --model qwen3-coder $argv
end
