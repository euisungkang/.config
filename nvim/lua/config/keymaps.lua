-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("v", "J", ":m '>+1<CR>gv-gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv-gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("x", "<leader>p", '"_dP')

-- Clipboard (both "+ and "* map to the system CLIPBOARD; see vim.g.clipboard in options.lua)
vim.keymap.set("n", "<leader>y", '"+yy')
vim.keymap.set("v", "<leader>y", '"+y')
vim.keymap.set("n", "<leader>Y", '"+Y')

-- Abyss Delete
vim.keymap.set("n", "<leader>d", '"_d')
vim.keymap.set("v", "<leader>d", '"_d')

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- Neo Tree
vim.keymap.set("n", "<C-b>", "<Cmd>Neotree toggle<CR>")

-- UFO
vim.keymap.set("n", "zR", require("ufo").openAllFolds)
vim.keymap.set("n", "zM", require("ufo").closeAllFolds)

local mark = require("harpoon.mark")
local ui = require("harpoon.ui")

-- Harpoon
vim.keymap.set("n", "<leader>a", function()
  -- Harpoon errors on buffers without a file (dashboard, scratch, sidebars).
  if vim.bo.buftype ~= "" or vim.api.nvim_buf_get_name(0) == "" then
    vim.notify("Harpoon: current buffer is not a file", vim.log.levels.WARN)
    return
  end
  mark.add_file()
end)
vim.keymap.set("n", "<C-a>", ui.toggle_quick_menu)

for i = 1, 9 do
  vim.keymap.set("n", "<leader>" .. i, function()
    ui.nav_file(i)
  end)
end

-- TMUX VIM NAV (for non-Hyprland / tmux systems: re-enable tmux.lua and swap
-- the Hyprland block below for this one)
-- vim.keymap.set("n", "<C-j>", ":TmuxNavigateDown<CR>", { silent = true })
-- vim.keymap.set("n", "<C-k>", ":TmuxNavigateUp<CR>", { silent = true })
-- vim.keymap.set("n", "<C-h>", ":TmuxNavigateLeft<CR>", { silent = true })
-- vim.keymap.set("n", "<C-l>", ":TmuxNavigateRight<CR>", { silent = true })

-- Ctrl+hjkl: move between Neovim splits; at the edge, hand focus off to the
-- neighbouring Hyprland window. Hyprland forwards these keys here via
-- ~/.config/hypr/scripts/nvim-nav.sh when nvim is the focused window.
local function win_nav(vim_dir, hypr_dir)
  return function()
    local prev = vim.api.nvim_get_current_win()
    vim.cmd.wincmd(vim_dir)
    if vim.api.nvim_get_current_win() == prev then
      -- Already at the edge split: fall through to Hyprland.
      vim.system({ "hyprctl", "dispatch", "movefocus", hypr_dir })
    end
  end
end

vim.keymap.set("n", "<C-h>", win_nav("h", "l"), { silent = true, desc = "Focus left split / Hypr window" })
vim.keymap.set("n", "<C-l>", win_nav("l", "r"), { silent = true, desc = "Focus right split / Hypr window" })
vim.keymap.set("n", "<C-j>", win_nav("j", "d"), { silent = true, desc = "Focus lower split / Hypr window" })
vim.keymap.set("n", "<C-k>", win_nav("k", "u"), { silent = true, desc = "Focus upper split / Hypr window" })
