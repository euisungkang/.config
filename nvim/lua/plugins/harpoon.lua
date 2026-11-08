return {
  "theprimeagen/harpoon",
  init = function()
    -- Harpoon already stores paths relative to nvim's cwd. For deep trees
    -- (Kotlin packages etc.) shorten the *display* in the Ctrl+A menu by
    -- concealing everything except the last three path segments (two parent
    -- dirs + the file), regardless of how deep the project is. The buffer text
    -- is untouched, so saving/reordering the menu still works.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "harpoon",
      callback = function()
        -- Harpoon's own Filetype autocmd calls clearmatches(), which would wipe
        -- our match, so defer until after it has run.
        local win = vim.api.nvim_get_current_win()
        vim.schedule(function()
          if not vim.api.nvim_win_is_valid(win) then
            return
          end
          vim.wo[win].conceallevel = 2
          vim.wo[win].concealcursor = "nvic"
          vim.api.nvim_win_call(win, function()
            vim.fn.matchadd("Conceal", [[\v^.*/\ze[^/]+/[^/]+/[^/]+$]], 10, -1, { conceal = "…" })
          end)
        end)
      end,
    })
  end,
}
