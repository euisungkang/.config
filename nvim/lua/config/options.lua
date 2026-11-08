-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.clipboard = ""
-- vim.opt.clipboard = "unnamed"

-- On Wayland, "* defaults to the PRIMARY selection (middle-click buffer), which
-- is not the clipboard that Ctrl+V reads across apps. Remap "* to the CLIPBOARD
-- selection so "*yy is available system-wide. Plain `yy` stays Neovim-only
-- because vim.opt.clipboard is "".
if vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1 then
  vim.g.clipboard = {
    name = "wl-clipboard (* -> CLIPBOARD)",
    copy = {
      ["+"] = { "wl-copy", "--type", "text/plain" },
      ["*"] = { "wl-copy", "--type", "text/plain" },
    },
    paste = {
      ["+"] = { "wl-paste", "--no-newline" },
      ["*"] = { "wl-paste", "--no-newline" },
    },
    cache_enabled = true,
  }
end

vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50
-- vim.opt.colorcolumn = "80"

vim.g.mapleader = " "
vim.g.javaScript_fold = 1

vim.keymap.set("n", "md", ":MarkdownPreview<CR>")
vim.keymap.set("n", "dmd", ":MarkdownPreviewStop<CR>")

-- UFO
vim.o.foldcolumn = "1" -- '0' is not bad
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true
