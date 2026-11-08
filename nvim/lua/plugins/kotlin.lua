-- Use JetBrains' kotlin-lsp instead of fwcd/kotlin-language-server.
-- kotlin-language-server crashes on startup with JDK 25 ("IllegalArgumentException: 25.0.4.1"),
-- which left Kotlin buffers with no LSP (so `gd` did nothing).
--
-- kotlin-lsp is installed manually because mason's registry URL 404s:
--   ~/.local/share/kotlin-lsp/<version>/kotlin-server-<version>/  (bundles its own JRE)
--   ~/.local/share/kotlin-lsp/current -> that directory
-- Releases: https://github.com/Kotlin/kotlin-lsp/releases
return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      kotlin_language_server = { enabled = false },
      kotlin_lsp = {
        mason = false,
        cmd = { vim.fn.expand("~/.local/share/kotlin-lsp/current/bin/intellij-server"), "--stdio" },
      },
    },
  },
}
