local colors_path = vim.fn.expand("~/.local/state/caelestia/theme/nvim-colors.lua")

local function watch_colors()
  local w = vim.uv.new_fs_event()
  if not w then
    return
  end
  w:start(colors_path, {}, function(err)
    if err then
      return
    end
    w:stop()
    vim.schedule(function()
      vim.cmd.colorscheme("caelestia")
      watch_colors()
    end)
  end)
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "caelestia",
    },
    init = function()
      watch_colors()
    end,
  },
}
