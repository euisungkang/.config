local theme = require('lualine.themes.dracula')
theme.normal.c.bg = nil

require('lualine').setup {
    options = {
        theme = theme
    },
    sections = {
        lualine_a = {'mode'},
        lualine_b = {'branch', 'diff', 'diagnostics'},
        lualine_c = {'filename'},
        lualine_x = {'encoding'},
        lualine_y = {'progress'},
        lualine_z = {'location'}
    },
}
