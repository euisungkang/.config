require("catppuccin").setup({

    transparent_background = false,

    flavour = "mocha",

    integration = {
        coc_nvim = true,
        harpoon = true,
        mason = true,
    }
})

function reloadColors(color)

    color = color or "catppuccin-mocha"
    vim.cmd.colorscheme(color)

    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "Normal", { fg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { fg = "none" })

    vim.api.nvim_set_hl(0, "LineNr", { fg = "#F5BA78" })
end

reloadColors()
