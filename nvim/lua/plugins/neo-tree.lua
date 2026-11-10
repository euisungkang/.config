return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = false, -- default state; H toggles this flag
          hide_dotfiles = false, -- dotfiles always shown (not affected by visible)
          hide_gitignored = false, -- show gitignored files (e.g. .env) by default
          hide_by_name = { "node_modules", ".git" }, -- still hidden by default; H reveals them
          hide_hidden = false, -- Windows-only "hidden" attribute
        },
      },
      window = {
        mappings = {
          ["<C-b>"] = "close_window",
        },
      },
    },
  },
}
