local colors_path = vim.fn.expand("~/.local/state/caelestia/theme/nvim-colors.lua")

local function load_colors()
  local ok, colors = pcall(dofile, colors_path)
  if not ok then
    return nil
  end
  return colors
end

local function apply_theme(colors)
  vim.cmd("hi clear")

  local bg = "NONE"
  local float_bg = colors.surface_container

  local hl = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- Editor
  hl("Normal", { fg = colors.text, bg = bg })
  hl("NormalFloat", { fg = colors.text, bg = "NONE" })
  hl("NormalNC", { fg = colors.text, bg = bg })
  hl("Cursor", { fg = colors.base, bg = colors.primary })
  hl("CursorLine", { bg = colors.surface0 })
  hl("CursorColumn", { bg = colors.surface0 })
  hl("ColorColumn", { bg = colors.surface0 })
  hl("LineNr", { fg = colors.primary })
  hl("CursorLineNr", { fg = colors.primary, bold = true })
  hl("SignColumn", { fg = colors.surface1, bg = bg })
  hl("VertSplit", { fg = colors.outline_variant })
  hl("WinSeparator", { fg = colors.outline_variant })
  hl("Folded", { fg = colors.overlay0, bg = colors.surface1 })
  hl("FoldColumn", { fg = colors.overlay0, bg = bg })
  hl("NonText", { fg = colors.surface1 })
  hl("SpecialKey", { fg = colors.surface1 })
  hl("Conceal", { fg = colors.overlay1 })
  hl("Directory", { fg = colors.primary })
  hl("Title", { fg = colors.primary, bold = true })
  hl("ErrorMsg", { fg = colors.error, bold = true })
  hl("WarningMsg", { fg = colors.peach, bold = true })
  hl("MoreMsg", { fg = colors.primary })
  hl("ModeMsg", { fg = colors.text })
  hl("Question", { fg = colors.primary })
  hl("EndOfBuffer", { fg = bg })

  -- Search & visual
  hl("Search", { fg = colors.base, bg = colors.primary })
  hl("IncSearch", { fg = colors.base, bg = colors.secondary })
  hl("CurSearch", { fg = colors.base, bg = colors.tertiary })
  hl("Visual", { bg = colors.surface2 })
  hl("VisualNOS", { bg = colors.surface2 })

  -- Pmenu
  hl("Pmenu", { fg = colors.text, bg = float_bg })
  hl("PmenuSel", { fg = colors.base, bg = colors.primary })
  hl("PmenuSbar", { bg = colors.surface1 })
  hl("PmenuThumb", { bg = colors.overlay0 })

  -- Statusline & tabline
  hl("StatusLine", { fg = colors.text, bg = colors.surface0 })
  hl("StatusLineNC", { fg = colors.subtext0, bg = colors.surface0 })
  hl("TabLine", { fg = colors.subtext0, bg = colors.surface0 })
  hl("TabLineFill", { bg = colors.surface0 })
  hl("TabLineSel", { fg = colors.primary, bg = colors.surface1 })
  hl("WinBar", { fg = colors.text, bg = bg })
  hl("WinBarNC", { fg = colors.subtext0, bg = bg })

  -- Diff
  hl("DiffAdd", { bg = "#2a3525" })
  hl("DiffChange", { bg = "#1f2a38" })
  hl("DiffDelete", { fg = colors.red, bg = "#3a2020" })
  hl("DiffText", { bg = "#2a3a4a" })

  -- Spelling
  hl("SpellBad", { undercurl = true, sp = colors.error })
  hl("SpellCap", { undercurl = true, sp = colors.primary })
  hl("SpellLocal", { undercurl = true, sp = colors.secondary })
  hl("SpellRare", { undercurl = true, sp = colors.tertiary })

  -- Syntax
  hl("Comment", { fg = colors.overlay1, italic = true })
  hl("Constant", { fg = colors.peach })
  hl("String", { fg = colors.green })
  hl("Character", { fg = colors.teal })
  hl("Number", { fg = colors.peach })
  hl("Boolean", { fg = colors.peach })
  hl("Float", { fg = colors.peach })
  hl("Identifier", { fg = colors.flamingo })
  hl("Function", { fg = colors.blue, bold = true })
  hl("Statement", { fg = colors.mauve })
  hl("Conditional", { fg = colors.mauve })
  hl("Repeat", { fg = colors.mauve })
  hl("Label", { fg = colors.sapphire })
  hl("Operator", { fg = colors.sky })
  hl("Keyword", { fg = colors.mauve })
  hl("Exception", { fg = colors.mauve })
  hl("PreProc", { fg = colors.pink })
  hl("Include", { fg = colors.mauve })
  hl("Define", { fg = colors.mauve })
  hl("Macro", { fg = colors.mauve })
  hl("PreCondit", { fg = colors.mauve })
  hl("Type", { fg = colors.yellow })
  hl("StorageClass", { fg = colors.yellow })
  hl("Structure", { fg = colors.yellow })
  hl("Typedef", { fg = colors.yellow })
  hl("Special", { fg = colors.pink })
  hl("SpecialChar", { fg = colors.pink })
  hl("Tag", { fg = colors.lavender })
  hl("Delimiter", { fg = colors.subtext1 })
  hl("SpecialComment", { fg = colors.overlay2, italic = true })
  hl("Debug", { fg = colors.peach })
  hl("Underlined", { underline = true })
  hl("Ignore", {})
  hl("Error", { fg = colors.error })
  hl("Todo", { fg = colors.base, bg = colors.primary, bold = true })

  -- Treesitter
  hl("@variable", { fg = colors.text })
  hl("@variable.builtin", { fg = colors.red })
  hl("@variable.parameter", { fg = colors.maroon, italic = true })
  hl("@variable.member", { fg = colors.lavender })
  hl("@constant", { fg = colors.peach })
  hl("@constant.builtin", { fg = colors.peach })
  hl("@constant.macro", { fg = colors.mauve })
  hl("@module", { fg = colors.lavender })
  hl("@string", { fg = colors.green })
  hl("@string.escape", { fg = colors.pink })
  hl("@string.regexp", { fg = colors.peach })
  hl("@character", { fg = colors.teal })
  hl("@number", { fg = colors.peach })
  hl("@boolean", { fg = colors.peach })
  hl("@float", { fg = colors.peach })
  hl("@function", { fg = colors.blue, bold = true })
  hl("@function.builtin", { fg = colors.peach })
  hl("@function.call", { fg = colors.blue })
  hl("@function.macro", { fg = colors.teal })
  hl("@function.method", { fg = colors.blue })
  hl("@function.method.call", { fg = colors.blue })
  hl("@constructor", { fg = colors.sapphire })
  hl("@operator", { fg = colors.sky })
  hl("@keyword", { fg = colors.mauve })
  hl("@keyword.coroutine", { fg = colors.mauve })
  hl("@keyword.function", { fg = colors.mauve })
  hl("@keyword.operator", { fg = colors.mauve })
  hl("@keyword.return", { fg = colors.mauve })
  hl("@keyword.import", { fg = colors.mauve })
  hl("@keyword.conditional", { fg = colors.mauve })
  hl("@keyword.repeat", { fg = colors.mauve })
  hl("@keyword.exception", { fg = colors.mauve })
  hl("@type", { fg = colors.yellow })
  hl("@type.builtin", { fg = colors.yellow, italic = true })
  hl("@type.definition", { fg = colors.yellow })
  hl("@type.qualifier", { fg = colors.mauve })
  hl("@attribute", { fg = colors.peach })
  hl("@property", { fg = colors.lavender })
  hl("@comment", { fg = colors.overlay1, italic = true })
  hl("@punctuation.delimiter", { fg = colors.subtext1 })
  hl("@punctuation.bracket", { fg = colors.subtext1 })
  hl("@punctuation.special", { fg = colors.sky })
  hl("@tag", { fg = colors.mauve })
  hl("@tag.attribute", { fg = colors.teal, italic = true })
  hl("@tag.delimiter", { fg = colors.sky })
  hl("@markup.heading", { fg = colors.primary, bold = true })
  hl("@markup.italic", { italic = true })
  hl("@markup.strong", { bold = true })
  hl("@markup.strikethrough", { strikethrough = true })
  hl("@markup.link", { fg = colors.blue })
  hl("@markup.link.url", { fg = colors.rosewater, italic = true, underline = true })
  hl("@markup.raw", { fg = colors.green })
  hl("@markup.list", { fg = colors.mauve })

  -- LSP semantic tokens
  hl("@lsp.type.class", { fg = colors.yellow })
  hl("@lsp.type.decorator", { fg = colors.peach })
  hl("@lsp.type.enum", { fg = colors.teal })
  hl("@lsp.type.enumMember", { fg = colors.peach })
  hl("@lsp.type.function", { fg = colors.blue })
  hl("@lsp.type.interface", { fg = colors.yellow })
  hl("@lsp.type.macro", { fg = colors.mauve })
  hl("@lsp.type.method", { fg = colors.blue })
  hl("@lsp.type.namespace", { fg = colors.lavender })
  hl("@lsp.type.parameter", { fg = colors.maroon })
  hl("@lsp.type.property", { fg = colors.lavender })
  hl("@lsp.type.struct", { fg = colors.yellow })
  hl("@lsp.type.type", { fg = colors.yellow })
  hl("@lsp.type.typeParameter", { fg = colors.yellow })
  hl("@lsp.type.variable", { fg = colors.text })

  -- Diagnostics
  hl("DiagnosticError", { fg = colors.error })
  hl("DiagnosticWarn", { fg = colors.peach })
  hl("DiagnosticInfo", { fg = colors.primary })
  hl("DiagnosticHint", { fg = colors.teal })
  hl("DiagnosticOk", { fg = colors.success })
  hl("DiagnosticUnderlineError", { undercurl = true, sp = colors.error })
  hl("DiagnosticUnderlineWarn", { undercurl = true, sp = colors.peach })
  hl("DiagnosticUnderlineInfo", { undercurl = true, sp = colors.primary })
  hl("DiagnosticUnderlineHint", { undercurl = true, sp = colors.teal })
  hl("DiagnosticVirtualTextError", { fg = colors.error, bg = colors.surface0 })
  hl("DiagnosticVirtualTextWarn", { fg = colors.peach, bg = colors.surface0 })
  hl("DiagnosticVirtualTextInfo", { fg = colors.primary, bg = colors.surface0 })
  hl("DiagnosticVirtualTextHint", { fg = colors.teal, bg = colors.surface0 })

  -- Git signs
  hl("GitSignsAdd", { fg = colors.success })
  hl("GitSignsChange", { fg = colors.primary })
  hl("GitSignsDelete", { fg = colors.error })

  -- Telescope
  hl("TelescopeNormal", { fg = colors.text, bg = "NONE" })
  hl("TelescopeBorder", { fg = colors.outline_variant, bg = "NONE" })
  hl("TelescopeTitle", { fg = colors.primary, bold = true })
  hl("TelescopeSelection", { bg = colors.surface1 })
  hl("TelescopeSelectionCaret", { fg = colors.primary })
  hl("TelescopeMatching", { fg = colors.primary, bold = true })
  hl("TelescopePromptNormal", { fg = colors.text, bg = "NONE" })
  hl("TelescopePromptBorder", { fg = colors.outline_variant, bg = "NONE" })
  hl("TelescopePromptTitle", { fg = colors.primary, bold = true })
  hl("TelescopePromptPrefix", { fg = colors.primary })

  -- Neo-tree
  hl("NeoTreeNormal", { fg = colors.text, bg = bg })
  hl("NeoTreeNormalNC", { fg = colors.text, bg = bg })
  hl("NeoTreeDirectoryName", { fg = colors.primary })
  hl("NeoTreeDirectoryIcon", { fg = colors.primary })
  hl("NeoTreeRootName", { fg = colors.primary, bold = true })
  hl("NeoTreeFileName", { fg = colors.text })
  hl("NeoTreeGitAdded", { fg = colors.success })
  hl("NeoTreeGitModified", { fg = colors.primary })
  hl("NeoTreeGitDeleted", { fg = colors.error })
  hl("NeoTreeIndentMarker", { fg = colors.surface2 })

  -- Which-key
  hl("WhichKey", { fg = colors.primary })
  hl("WhichKeyGroup", { fg = colors.blue })
  hl("WhichKeyDesc", { fg = colors.text })
  hl("WhichKeySeparator", { fg = colors.overlay0 })
  hl("WhichKeyFloat", { bg = "NONE" })

  -- Noice / notify
  hl("NoiceCmdline", { fg = colors.text })
  hl("NoiceCmdlinePopup", { fg = colors.text, bg = float_bg })
  hl("NoiceCmdlinePopupBorder", { fg = colors.outline_variant })
  hl("NotifyINFOBorder", { fg = colors.primary })
  hl("NotifyINFOTitle", { fg = colors.primary })
  hl("NotifyINFOIcon", { fg = colors.primary })
  hl("NotifyWARNBorder", { fg = colors.peach })
  hl("NotifyWARNTitle", { fg = colors.peach })
  hl("NotifyWARNIcon", { fg = colors.peach })
  hl("NotifyERRORBorder", { fg = colors.error })
  hl("NotifyERRORTitle", { fg = colors.error })
  hl("NotifyERRORIcon", { fg = colors.error })

  -- Dashboard / alpha
  hl("DashboardHeader", { fg = colors.primary })
  hl("DashboardFooter", { fg = colors.overlay1, italic = true })
  hl("DashboardShortCut", { fg = colors.secondary })
  hl("DashboardIcon", { fg = colors.primary })
  hl("DashboardDesc", { fg = colors.text })
  hl("DashboardKey", { fg = colors.primary })

  -- Indent blankline
  hl("IblIndent", { fg = colors.surface1 })
  hl("IblScope", { fg = colors.primary })

  -- Flash
  hl("FlashLabel", { fg = colors.base, bg = colors.primary, bold = true })
  hl("FlashMatch", { fg = colors.text, bg = colors.surface2 })
  hl("FlashCurrent", { fg = colors.base, bg = colors.secondary })

  -- Mini
  hl("MiniStatuslineFilename", { fg = colors.text })
  hl("MiniStatuslineDevinfo", { fg = colors.subtext1 })
  hl("MiniIconsAzure", { fg = colors.sapphire })
  hl("MiniIconsBlue", { fg = colors.blue })
  hl("MiniIconsCyan", { fg = colors.teal })
  hl("MiniIconsGreen", { fg = colors.green })
  hl("MiniIconsGrey", { fg = colors.overlay1 })
  hl("MiniIconsOrange", { fg = colors.peach })
  hl("MiniIconsPurple", { fg = colors.mauve })
  hl("MiniIconsRed", { fg = colors.red })
  hl("MiniIconsYellow", { fg = colors.yellow })

  -- Snacks
  hl("SnacksIndent", { fg = colors.surface1 })
  hl("SnacksIndentScope", { fg = colors.primary })

  -- Trouble
  hl("TroubleNormal", { fg = colors.text, bg = bg })
  hl("TroubleText", { fg = colors.text })

  -- Mason
  hl("MasonNormal", { fg = colors.text, bg = float_bg })
  hl("MasonHeader", { fg = colors.base, bg = colors.primary, bold = true })
  hl("MasonHighlight", { fg = colors.primary })
  hl("MasonHighlightBlock", { fg = colors.base, bg = colors.primary })

  -- Lazy
  hl("LazyButton", { fg = colors.text, bg = colors.surface1 })
  hl("LazyButtonActive", { fg = colors.base, bg = colors.primary })
  hl("LazyH1", { fg = colors.base, bg = colors.primary, bold = true })

  -- Illuminate
  hl("IlluminatedWordText", { bg = colors.surface1 })
  hl("IlluminatedWordRead", { bg = colors.surface1 })
  hl("IlluminatedWordWrite", { bg = colors.surface1 })

  -- Markdown
  hl("markdownH1", { fg = colors.primary, bold = true })
  hl("markdownH2", { fg = colors.secondary, bold = true })
  hl("markdownH3", { fg = colors.tertiary, bold = true })
  hl("markdownH4", { fg = colors.teal, bold = true })
  hl("markdownCode", { fg = colors.green })
  hl("markdownCodeBlock", { fg = colors.green })
  hl("markdownUrl", { fg = colors.blue, underline = true })
  hl("markdownLinkText", { fg = colors.blue })
  hl("markdownBold", { bold = true })
  hl("markdownItalic", { italic = true })

  -- CMP
  hl("CmpItemAbbr", { fg = colors.text })
  hl("CmpItemAbbrMatch", { fg = colors.primary, bold = true })
  hl("CmpItemAbbrMatchFuzzy", { fg = colors.primary, bold = true })
  hl("CmpItemAbbrDeprecated", { fg = colors.overlay0, strikethrough = true })
  hl("CmpItemKind", { fg = colors.blue })
  hl("CmpItemMenu", { fg = colors.subtext0 })
end

local colors = load_colors()
if not colors then
  vim.notify("Caelestia colors not found at " .. colors_path, vim.log.levels.WARN)
  return
end

vim.g.colors_name = "caelestia"
apply_theme(colors)
