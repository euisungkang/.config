require 'nvim-treesitter.configs'.setup {
  ensure_installed = { "javascript", "typescript", "c", "lua", "vim", "vimdoc", "query", "css", "svelte"},

  sync_install = false,

  auto_install = true,

  ignore_install = { "help" },

  highlight = {
    enable = true,

    additional_vim_regex_highlighting = false,
  },
}
