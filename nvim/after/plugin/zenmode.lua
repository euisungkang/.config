require("zen-mode").setup {
    window = {
        width = 75,
        options = {
            number = true,
            relativenumber = true,
        }
    },
}

vim.keymap.set("n", "<leader><CR>", function()
    require("zen-mode").toggle()
    vim.wo.wrap = false
    reloadColors()
end)
