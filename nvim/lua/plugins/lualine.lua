local theme = require("lualine.themes.dracula")
theme.normal.c.bg = nil

return {
  "nvim-lualine/lualine.nvim",
  opts = function()
    local opts = {
      sections = {
        lualine_z = {},
      },
    }
    return opts
  end,
}
