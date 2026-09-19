-- Modified for Blix: oxwm default palette (2026-09-16).
-- Source: tonybanters/oxwm templates/config.lua at
-- fc4ada9ac4ee8e34ace203290a2b14d10e4671cc.
-- Maintains Blix's Seafoam highlight mappings and colorscheme name.
-- Dim surfaces, selection, comments, and yellow supplement oxwm's UI palette.

local c = {
  bg = "#1a1b26",
  fg = "#bbbbbb",
  cursor = "#6dade3",
  cursor_text = "#1a1b26",
  selection_bg = "#283457",
  selection_fg = "#a9b1d6",

  black = "#202230",
  red = "#f7768e",
  green = "#9ece6a",
  yellow = "#e0af68",
  blue = "#6dade3",
  magenta = "#34324a",
  cyan = "#0db9d7",
  white = "#bbbbbb",
  bright_black = "#737aa2",
  bright_red = "#f7768e",
  bright_green = "#9ece6a",
  bright_yellow = "#e0af68",
  bright_blue = "#7aa2f7",
  bright_magenta = "#ad8ee6",
  bright_cyan = "#0db9d7",
  bright_white = "#a9b1d6",
}

local ansi = {
  c.black,
  c.red,
  c.green,
  c.yellow,
  c.blue,
  c.magenta,
  c.cyan,
  c.white,
  c.bright_black,
  c.bright_red,
  c.bright_green,
  c.bright_yellow,
  c.bright_blue,
  c.bright_magenta,
  c.bright_cyan,
  c.bright_white,
}

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.o.background = "dark"
vim.o.termguicolors = true
vim.g.colors_name = "seafoam"

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

local function link_groups(groups, target)
  for _, group in ipairs(groups) do
    hi(group, { link = target })
  end
end

local function set_groups(groups, opts)
  for _, group in ipairs(groups) do
    hi(group, opts)
  end
end

local function apply()
  for index, color in ipairs(ansi) do
    vim.g["terminal_color_" .. (index - 1)] = color
  end
  vim.g.terminal_color_background = c.bg
  vim.g.terminal_color_foreground = c.fg

  -- Editor and window chrome.
  hi("Normal", { fg = c.fg, bg = c.bg })
  hi("NormalNC", { fg = c.fg, bg = c.bg })
  hi("NormalFloat", { fg = c.fg, bg = c.bg })
  hi("FloatBorder", { fg = c.bright_magenta, bg = c.bg })
  hi("FloatTitle", { fg = c.fg, bg = c.magenta, bold = true })
  hi("FloatFooter", { fg = c.bright_black, bg = c.bg })
  hi("Cursor", { fg = c.cursor_text, bg = c.cursor })
  hi("lCursor", { fg = c.cursor_text, bg = c.cursor })
  hi("TermCursor", { fg = c.cursor_text, bg = c.cursor })
  hi("TermCursorNC", { fg = c.cursor_text, bg = c.cursor })
  hi("CursorLine", { bg = c.black })
  hi("CursorColumn", { bg = c.black })
  hi("ColorColumn", { bg = c.black })
  hi("CursorLineNr", { fg = c.bright_yellow, bg = c.black, bold = true })
  hi("LineNr", { fg = c.bright_black, bg = c.bg })
  hi("LineNrAbove", { fg = c.bright_black, bg = c.bg })
  hi("LineNrBelow", { fg = c.bright_black, bg = c.bg })
  hi("SignColumn", { fg = c.bright_black, bg = c.bg })
  hi("FoldColumn", { fg = c.bright_black, bg = c.bg })
  hi("Folded", { fg = c.bright_blue, bg = c.black })
  hi("WinSeparator", { fg = c.magenta, bg = c.bg })
  hi("VertSplit", { link = "WinSeparator" })
  hi("EndOfBuffer", { fg = c.bg, bg = c.bg })
  hi("NonText", { fg = c.bright_black })
  hi("SpecialKey", { fg = c.bright_black })
  hi("Whitespace", { fg = c.bright_black })
  hi("Conceal", { fg = c.bright_magenta })
  hi("Directory", { fg = c.bright_blue, bold = true })
  hi("Title", { fg = c.bright_blue, bold = true })
  hi("Question", { fg = c.bright_green })
  hi("MoreMsg", { fg = c.bright_green })
  hi("ModeMsg", { fg = c.fg, bold = true })
  hi("MsgArea", { fg = c.fg, bg = c.bg })
  hi("MsgSeparator", { fg = c.black, bg = c.bg })
  hi("ErrorMsg", { fg = c.bright_red, bold = true })
  hi("WarningMsg", { fg = c.bright_yellow, bold = true })
  hi("WildMenu", { fg = c.selection_fg, bg = c.selection_bg, bold = true })
  hi("QuickFixLine", { fg = c.fg, bg = c.black, bold = true })
  hi("MatchParen", { fg = c.bright_yellow, bg = c.black, bold = true })
  hi("Substitute", { fg = c.cursor_text, bg = c.bright_cyan, bold = true })
  hi("PaddedWhitespaces", { bg = c.black })

  hi("StatusLine", { fg = c.fg, bg = c.black, bold = true })
  hi("StatusLineNC", { fg = c.bright_black, bg = c.black })
  hi("StatusLineTerm", { fg = c.fg, bg = c.black, bold = true })
  hi("StatusLineTermNC", { fg = c.bright_black, bg = c.black })
  hi("WinBar", { fg = c.fg, bg = c.bg, bold = true })
  hi("WinBarNC", { fg = c.bright_black, bg = c.bg })
  hi("TabLine", { fg = c.white, bg = c.black })
  hi("TabLineFill", { fg = c.bright_black, bg = c.bg })
  hi("TabLineSel", { fg = c.fg, bg = c.magenta, bold = true })

  -- Cursor, selection, search, and completion menus.
  hi("Visual", { fg = c.selection_fg, bg = c.selection_bg })
  hi("VisualNOS", { fg = c.selection_fg, bg = c.selection_bg })
  hi("Search", { fg = c.selection_fg, bg = c.selection_bg })
  hi("IncSearch", { fg = c.cursor_text, bg = c.bright_cyan, bold = true })
  hi("CurSearch", { fg = c.cursor_text, bg = c.bright_yellow, bold = true })
  hi("Pmenu", { fg = c.fg, bg = c.black })
  hi("PmenuSel", { fg = c.selection_fg, bg = c.selection_bg, bold = true })
  hi("PmenuKind", { fg = c.bright_cyan, bg = c.black })
  hi("PmenuKindSel", { fg = c.selection_fg, bg = c.selection_bg, bold = true })
  hi("PmenuExtra", { fg = c.bright_black, bg = c.black })
  hi("PmenuExtraSel", { fg = c.white, bg = c.selection_bg })
  hi("PmenuSbar", { bg = c.magenta })
  hi("PmenuThumb", { bg = c.bright_magenta })

  -- Built-in syntax groups.
  hi("Comment", { fg = c.bright_black, italic = true })
  hi("Constant", { fg = c.bright_yellow })
  hi("String", { fg = c.bright_green })
  hi("Character", { fg = c.bright_green })
  hi("Number", { fg = c.bright_yellow })
  hi("Boolean", { fg = c.bright_yellow, bold = true })
  hi("Float", { fg = c.bright_yellow })
  hi("Identifier", { fg = c.fg })
  hi("Function", { fg = c.bright_blue })
  hi("Statement", { fg = c.bright_magenta, bold = true })
  hi("Conditional", { fg = c.bright_magenta, bold = true })
  hi("Repeat", { fg = c.bright_magenta, bold = true })
  hi("Label", { fg = c.bright_magenta })
  hi("Operator", { fg = c.bright_cyan })
  hi("Keyword", { fg = c.bright_magenta, bold = true })
  hi("Exception", { fg = c.bright_red, bold = true })
  hi("PreProc", { fg = c.bright_magenta })
  hi("Include", { fg = c.bright_magenta })
  hi("Define", { fg = c.bright_magenta })
  hi("Macro", { fg = c.bright_magenta })
  hi("PreCondit", { fg = c.bright_magenta })
  hi("Type", { fg = c.bright_cyan })
  hi("StorageClass", { fg = c.bright_cyan, bold = true })
  hi("Structure", { fg = c.bright_cyan })
  hi("Typedef", { fg = c.bright_cyan })
  hi("Special", { fg = c.bright_cyan })
  hi("SpecialChar", { fg = c.bright_cyan })
  hi("Tag", { fg = c.bright_blue })
  hi("Delimiter", { fg = c.white })
  hi("Debug", { fg = c.bright_red })
  hi("Underlined", { fg = c.bright_blue, underline = true })
  hi("Bold", { fg = c.fg, bold = true })
  hi("Italic", { fg = c.fg, italic = true })
  hi("Error", { fg = c.bright_red, bold = true })
  hi("Todo", { fg = c.cursor_text, bg = c.bright_yellow, bold = true })

  -- Treesitter captures and semantic tokens.
  link_groups({ "@comment", "@comment.documentation" }, "Comment")
  link_groups({ "@constant", "@constant.builtin", "@constant.macro" }, "Constant")
  link_groups({ "@string", "@string.documentation", "@string.regexp", "@string.special" }, "String")
  link_groups({ "@string.escape", "@string.regex", "@character", "@character.special" }, "SpecialChar")
  link_groups({ "@number", "@number.float", "@boolean" }, "Number")
  link_groups({
    "@function",
    "@function.builtin",
    "@function.call",
    "@function.macro",
    "@function.method",
    "@function.method.call",
  }, "Function")
  link_groups({ "@constructor", "@type", "@type.builtin", "@type.definition" }, "Type")
  link_groups({ "@variable", "@variable.builtin", "@variable.parameter" }, "Identifier")
  link_groups({ "@variable.member", "@property", "@field" }, "Identifier")
  link_groups({ "@parameter", "@parameter.reference" }, "Identifier")
  link_groups({ "@keyword", "@keyword.conditional", "@keyword.directive", "@keyword.exception" }, "Keyword")
  link_groups({ "@keyword.function", "@keyword.operator", "@keyword.return" }, "Statement")
  link_groups({ "@keyword.import", "@keyword.storage" }, "PreProc")
  link_groups({ "@operator" }, "Operator")
  link_groups({ "@label", "@namespace", "@module" }, "Label")
  link_groups({ "@punctuation.delimiter", "@punctuation.bracket", "@punctuation.special" }, "Delimiter")
  link_groups({ "@tag", "@tag.builtin", "@tag.attribute", "@tag.delimiter" }, "Tag")
  link_groups({ "@attribute", "@markup.attribute" }, "Identifier")
  link_groups({ "@markup.heading", "@markup.heading.1", "@markup.heading.2", "@markup.heading.3" }, "Title")
  link_groups({ "@markup.heading.4", "@markup.heading.5", "@markup.heading.6" }, "Title")
  link_groups({ "@markup.bold" }, "Bold")
  link_groups({ "@markup.italic" }, "Italic")
  link_groups({ "@markup.underline", "@markup.link.url" }, "Underlined")
  link_groups({ "@markup.raw", "@markup.raw.block" }, "String")
  link_groups({ "@markup.list", "@markup.quote" }, "Special")
  link_groups({ "@diff.plus" }, "DiffAdd")
  link_groups({ "@diff.minus" }, "DiffDelete")
  link_groups({ "@diff.delta" }, "DiffChange")
  link_groups({
    "@lsp.type.class",
    "@lsp.type.enum",
    "@lsp.type.interface",
    "@lsp.type.namespace",
    "@lsp.type.struct",
    "@lsp.type.type",
  }, "Type")
  link_groups({ "@lsp.type.function", "@lsp.type.method" }, "Function")
  link_groups({ "@lsp.type.parameter", "@lsp.type.variable", "@lsp.type.property" }, "Identifier")

  -- Diagnostics, references, and LSP UI.
  hi("DiagnosticError", { fg = c.bright_red, undercurl = true, sp = c.bright_red })
  hi("DiagnosticWarn", { fg = c.bright_yellow, undercurl = true, sp = c.bright_yellow })
  hi("DiagnosticInfo", { fg = c.bright_blue, undercurl = true, sp = c.bright_blue })
  hi("DiagnosticHint", { fg = c.bright_cyan, undercurl = true, sp = c.bright_cyan })
  hi("DiagnosticOk", { fg = c.bright_green })
  hi("DiagnosticVirtualTextError", { fg = c.bright_red, bg = c.black })
  hi("DiagnosticVirtualTextWarn", { fg = c.bright_yellow, bg = c.black })
  hi("DiagnosticVirtualTextInfo", { fg = c.bright_blue, bg = c.black })
  hi("DiagnosticVirtualTextHint", { fg = c.bright_cyan, bg = c.black })
  hi("DiagnosticVirtualTextOk", { fg = c.bright_green, bg = c.black })
  hi("DiagnosticSignError", { fg = c.bright_red, bg = c.bg })
  hi("DiagnosticSignWarn", { fg = c.bright_yellow, bg = c.bg })
  hi("DiagnosticSignInfo", { fg = c.bright_blue, bg = c.bg })
  hi("DiagnosticSignHint", { fg = c.bright_cyan, bg = c.bg })
  hi("DiagnosticSignOk", { fg = c.bright_green, bg = c.bg })
  hi("LspReferenceText", { bg = c.black })
  hi("LspReferenceRead", { bg = c.black })
  hi("LspReferenceWrite", { bg = c.black, bold = true })
  hi("LspCodeLens", { fg = c.bright_black, italic = true })
  hi("LspInlayHint", { fg = c.bright_black, bg = c.black, italic = true })
  hi("LspInfoBorder", { fg = c.bright_blue, bg = c.bg })

  -- Diff and Git signs.
  hi("DiffAdd", { fg = c.bright_green, bg = c.black })
  hi("DiffChange", { fg = c.bright_blue, bg = c.black })
  hi("DiffDelete", { fg = c.bright_red, bg = c.black })
  hi("DiffText", { fg = c.fg, bg = c.blue, bold = true })
  hi("Added", { fg = c.bright_green })
  hi("Changed", { fg = c.bright_blue })
  hi("Removed", { fg = c.bright_red })
  hi("GitSignsAdd", { fg = c.bright_green, bg = c.bg })
  hi("GitSignsChange", { fg = c.bright_blue, bg = c.bg })
  hi("GitSignsDelete", { fg = c.bright_red, bg = c.bg })
  hi("GitSignsChangedelete", { fg = c.bright_magenta, bg = c.bg })
  hi("GitSignsTopdelete", { fg = c.bright_red, bg = c.bg })
  hi("GitSignsUntracked", { fg = c.bright_cyan, bg = c.bg })
  hi("GitSignsCurrentLineBlame", { fg = c.bright_black, italic = true })
  hi("GitSignsDeleteVirtLn", { fg = c.bright_red, bg = c.black })
  hi("GitSignsDeleteVirtLnInLine", { fg = c.bright_red, bg = c.black })
  hi("GitSignsVirtLnum", { fg = c.bright_red, bg = c.black })

  -- Lualine and bufferline.
  local lualine_modes = {
    normal = c.bright_blue,
    insert = c.bright_green,
    visual = c.bright_magenta,
    replace = c.bright_red,
    command = c.bright_yellow,
    inactive = c.black,
  }
  for mode, color in pairs(lualine_modes) do
    hi("lualine_a_" .. mode, { fg = c.cursor_text, bg = color, bold = true })
    hi("lualine_b_" .. mode, { fg = c.fg, bg = c.black })
    hi("lualine_c_" .. mode, { fg = c.fg, bg = c.bg })
  end
  hi("lualine_x_filetype_DevIconLua", { fg = c.bright_blue, bg = c.bg })

  hi("BufferLineFill", { fg = c.bright_black, bg = c.bg })
  hi("BufferLineBackground", { fg = c.bright_black, bg = c.black })
  hi("BufferLineBuffer", { fg = c.bright_black, bg = c.black })
  hi("BufferLineBufferVisible", { fg = c.fg, bg = c.black })
  hi("BufferLineBufferSelected", { fg = c.fg, bg = c.bg, bold = true })
  hi("BufferLineTab", { fg = c.bright_black, bg = c.black })
  hi("BufferLineTabSelected", { fg = c.fg, bg = c.magenta, bold = true })
  hi("BufferLineTabClose", { fg = c.bright_red, bg = c.black })
  hi("BufferLineIndicatorSelected", { fg = c.bright_magenta, bg = c.bg })
  hi("BufferLineSeparator", { fg = c.bg, bg = c.black })
  hi("BufferLineSeparatorSelected", { fg = c.bg, bg = c.bg })
  hi("BufferLineModified", { fg = c.bright_yellow, bg = c.black })
  hi("BufferLineModifiedSelected", { fg = c.bright_yellow, bg = c.bg })
  hi("BufferLineCloseButton", { fg = c.bright_red, bg = c.black })
  hi("BufferLineCloseButtonSelected", { fg = c.bright_red, bg = c.bg })
  hi("BufferLineDuplicate", { fg = c.bright_black, bg = c.black, italic = true })
  hi("BufferLineDuplicateSelected", { fg = c.bright_magenta, bg = c.bg, italic = true })
  hi("BufferLineOffsetSeparator", { fg = c.magenta, bg = c.bg })
  hi("BufferLineError", { fg = c.bright_red, bg = c.black })
  hi("BufferLineErrorSelected", { fg = c.bright_red, bg = c.bg })
  hi("BufferLineWarning", { fg = c.bright_yellow, bg = c.black })
  hi("BufferLineWarningSelected", { fg = c.bright_yellow, bg = c.bg })
  hi("BufferLineInfo", { fg = c.bright_blue, bg = c.black })
  hi("BufferLineInfoSelected", { fg = c.bright_blue, bg = c.bg })
  hi("BufferLineHint", { fg = c.bright_cyan, bg = c.black })
  hi("BufferLineHintSelected", { fg = c.bright_cyan, bg = c.bg })

  -- Telescope, Snacks, and completion UI.
  hi("TelescopeNormal", { fg = c.fg, bg = c.bg })
  hi("TelescopeBorder", { fg = c.bright_magenta, bg = c.bg })
  hi("TelescopePromptNormal", { fg = c.fg, bg = c.black })
  hi("TelescopePromptBorder", { fg = c.bright_magenta, bg = c.black })
  hi("TelescopePromptTitle", { fg = c.cursor_text, bg = c.magenta, bold = true })
  hi("TelescopePreviewNormal", { fg = c.fg, bg = c.bg })
  hi("TelescopePreviewBorder", { fg = c.bright_blue, bg = c.bg })
  hi("TelescopePreviewTitle", { fg = c.cursor_text, bg = c.bright_blue, bold = true })
  hi("TelescopeResultsNormal", { fg = c.fg, bg = c.bg })
  hi("TelescopeResultsBorder", { fg = c.bright_magenta, bg = c.bg })
  hi("TelescopeResultsTitle", { fg = c.cursor_text, bg = c.magenta, bold = true })
  hi("TelescopeSelection", { fg = c.selection_fg, bg = c.selection_bg, bold = true })
  hi("TelescopeSelectionCaret", { fg = c.bright_yellow, bg = c.selection_bg, bold = true })
  hi("TelescopeMatching", { fg = c.bright_yellow, bold = true })
  hi("TelescopeMultiSelection", { fg = c.bright_cyan, bg = c.black })
  hi("TelescopeTitle", { fg = c.fg, bg = c.magenta, bold = true })

  hi("SnacksNormal", { fg = c.fg, bg = c.bg })
  hi("SnacksNormalNC", { fg = c.fg, bg = c.bg })
  hi("SnacksWinBar", { fg = c.fg, bg = c.black, bold = true })
  hi("SnacksWinBarNC", { fg = c.bright_black, bg = c.black })
  hi("SnacksWinSeparator", { fg = c.magenta, bg = c.bg })
  hi("SnacksTitle", { fg = c.fg, bg = c.magenta, bold = true })
  hi("SnacksFooter", { fg = c.bright_black, bg = c.bg })
  hi("SnacksFooterKey", { fg = c.bright_yellow, bg = c.bg, bold = true })
  hi("SnacksFooterDesc", { fg = c.fg, bg = c.bg })
  hi("SnacksWinKey", { fg = c.bright_yellow, bg = c.bg, bold = true })
  hi("SnacksWinKeyDesc", { fg = c.fg, bg = c.bg })
  hi("SnacksWinKeySep", { fg = c.bright_black, bg = c.bg })
  hi("SnacksDim", { fg = c.bright_black })
  hi("SnacksIndent", { fg = c.black })
  hi("SnacksIndentScope", { fg = c.magenta })
  hi("SnacksIndentChunk", { fg = c.bright_magenta })
  hi("SnacksInputNormal", { fg = c.fg, bg = c.black })
  hi("SnacksInputBorder", { fg = c.bright_magenta, bg = c.black })
  hi("SnacksInputTitle", { fg = c.cursor_text, bg = c.magenta, bold = true })
  hi("SnacksInputIcon", { fg = c.bright_yellow, bg = c.black })
  hi("SnacksScratch", { fg = c.fg, bg = c.bg })
  hi("SnacksScratchTitle", { fg = c.fg, bg = c.magenta, bold = true })
  hi("SnacksZen", { fg = c.fg, bg = c.bg })
  hi("SnacksZenIcon", { fg = c.bright_magenta, bg = c.bg })
  hi("SnacksStatusColumn", { fg = c.bright_black, bg = c.bg })
  hi("SnacksStatusColumnMark", { fg = c.bright_yellow, bg = c.bg })
  hi("SnacksDashboardNormal", { fg = c.fg, bg = c.bg })
  hi("SnacksDashboardTerminal", { fg = c.bright_green, bg = c.bg })
  hi("SnacksDashboardHeader", { fg = c.bright_magenta, bg = c.bg, bold = true })
  hi("SnacksDashboardIcon", { fg = c.bright_blue, bg = c.bg })
  hi("SnacksDashboardFile", { fg = c.fg, bg = c.bg })
  hi("SnacksDashboardDir", { fg = c.bright_blue, bg = c.bg })
  hi("SnacksDashboardSpecial", { fg = c.bright_cyan, bg = c.bg })
  hi("SnacksDashboardFooter", { fg = c.bright_black, bg = c.bg })
  hi("SnacksNotifierHistory", { fg = c.fg, bg = c.bg })
  hi("SnacksNotifierHistoryTitle", { fg = c.fg, bg = c.magenta, bold = true })
  hi("SnacksNotifierMinimal", { fg = c.fg, bg = c.bg })

  hi("SnacksPicker", { fg = c.fg, bg = c.bg })
  hi("SnacksPickerNormal", { fg = c.fg, bg = c.bg })
  hi("SnacksPickerBorder", { fg = c.bright_magenta, bg = c.bg })
  hi("SnacksPickerBox", { fg = c.fg, bg = c.bg })
  hi("SnacksPickerInput", { fg = c.fg, bg = c.black })
  hi("SnacksPickerInputBorder", { fg = c.bright_magenta, bg = c.black })
  hi("SnacksPickerInputSearch", { fg = c.bright_yellow, bg = c.black })
  hi("SnacksPickerPrompt", { fg = c.bright_yellow, bg = c.black, bold = true })
  hi("SnacksPickerList", { fg = c.fg, bg = c.bg })
  hi("SnacksPickerListBorder", { fg = c.bright_magenta, bg = c.bg })
  hi("SnacksPickerListCursorLine", { fg = c.selection_fg, bg = c.selection_bg, bold = true })
  hi("SnacksPickerPreview", { fg = c.fg, bg = c.bg })
  hi("SnacksPickerPreviewBorder", { fg = c.bright_blue, bg = c.bg })
  hi("SnacksPickerPreviewCursorLine", { fg = c.fg, bg = c.black })
  hi("SnacksPickerSelected", { fg = c.selection_fg, bg = c.selection_bg, bold = true })
  hi("SnacksPickerMatch", { fg = c.bright_yellow, bold = true })
  hi("SnacksPickerDir", { fg = c.bright_blue })
  hi("SnacksPickerFile", { fg = c.fg })
  hi("SnacksPickerDirectory", { fg = c.bright_blue, bold = true })
  hi("SnacksPickerDimmed", { fg = c.bright_black })
  hi("SnacksPickerComment", { fg = c.bright_black, italic = true })
  hi("SnacksPickerGitAdded", { fg = c.bright_green })
  hi("SnacksPickerGitModified", { fg = c.bright_blue })
  hi("SnacksPickerGitDeleted", { fg = c.bright_red })
  hi("SnacksPickerGitRenamed", { fg = c.bright_magenta })
  hi("SnacksPickerGitUntracked", { fg = c.bright_cyan })
  hi("SnacksPickerGitUnmerged", { fg = c.bright_red, bold = true })
  hi("SnacksPickerGitStaged", { fg = c.bright_green })
  hi("SnacksPickerGitBranch", { fg = c.bright_magenta })
  hi("SnacksPickerGitBranchCurrent", { fg = c.bright_green, bold = true })
  hi("SnacksPickerLspAttached", { fg = c.bright_green })
  hi("SnacksPickerLspDisabled", { fg = c.bright_red })
  hi("SnacksPickerLspUnavailable", { fg = c.bright_yellow })
  hi("SnacksPickerDiagnosticCode", { fg = c.bright_black })
  hi("SnacksPickerDiagnosticSource", { fg = c.bright_black })
  hi("SnacksPickerKeymapLhs", { fg = c.bright_yellow, bold = true })
  hi("SnacksPickerKeymapRhs", { fg = c.fg })
  hi("SnacksPickerLink", { fg = c.bright_blue, underline = true })
  hi("SnacksPickerLinkBroken", { fg = c.bright_red, underline = true })
  hi("SnacksPickerIcon", { fg = c.bright_blue })
  hi("SnacksPickerSpecial", { fg = c.bright_cyan })
  hi("SnacksPickerTime", { fg = c.bright_black })
  hi("SnacksPickerTotals", { fg = c.bright_black })
  hi("SnacksPickerSpinner", { fg = c.bright_yellow })
  hi("SnacksPickerTree", { fg = c.bright_black })
  hi("SnacksDiffAdd", { fg = c.bright_green, bg = c.black })
  hi("SnacksDiffDelete", { fg = c.bright_red, bg = c.black })
  hi("SnacksDiffContext", { fg = c.fg, bg = c.bg })
  hi("SnacksDiffConflict", { fg = c.bright_yellow, bg = c.black, bold = true })
  hi("SnacksDiffHeader", { fg = c.bright_magenta, bg = c.bg, bold = true })
  hi("SnacksDiffLabel", { fg = c.bright_blue })

  hi("BlinkCmpMenu", { fg = c.fg, bg = c.black })
  hi("BlinkCmpMenuBorder", { fg = c.bright_magenta, bg = c.black })
  hi("BlinkCmpMenuSelection", { fg = c.selection_fg, bg = c.selection_bg, bold = true })
  hi("BlinkCmpLabel", { fg = c.fg, bg = c.black })
  hi("BlinkCmpLabelMatch", { fg = c.bright_yellow, bg = c.black, bold = true })
  hi("BlinkCmpLabelDescription", { fg = c.bright_black, bg = c.black })
  hi("BlinkCmpLabelDetail", { fg = c.bright_blue, bg = c.black })
  hi("BlinkCmpLabelDeprecated", { fg = c.bright_red, bg = c.black, strikethrough = true })
  hi("BlinkCmpSource", { fg = c.bright_cyan, bg = c.black })
  hi("BlinkCmpKind", { fg = c.bright_magenta, bg = c.black })
  hi("BlinkCmpGhostText", { fg = c.bright_black })
  hi("BlinkCmpDoc", { fg = c.fg, bg = c.bg })
  hi("BlinkCmpDocBorder", { fg = c.bright_blue, bg = c.bg })
  hi("BlinkCmpDocCursorLine", { fg = c.fg, bg = c.black })
  hi("BlinkCmpDocSeparator", { fg = c.bright_black, bg = c.bg })
  hi("BlinkCmpSignatureHelp", { fg = c.fg, bg = c.bg })
  hi("BlinkCmpSignatureHelpBorder", { fg = c.bright_blue, bg = c.bg })
  hi("BlinkCmpSignatureHelpActiveParameter", { fg = c.bright_yellow, bold = true })

  -- Other LazyVim interfaces.
  hi("WhichKey", { fg = c.bright_blue, bold = true })
  hi("WhichKeyGroup", { fg = c.bright_magenta, bold = true })
  hi("WhichKeyDesc", { fg = c.fg })
  hi("WhichKeySeparator", { fg = c.bright_black })
  hi("WhichKeyFloat", { fg = c.fg, bg = c.bg })
  hi("WhichKeyValue", { fg = c.bright_black })
  hi("WhichKeyIcon", { fg = c.bright_cyan })
  hi("WhichKeyIconAzure", { fg = c.bright_blue })
  hi("WhichKeyIconBlue", { fg = c.bright_blue })
  hi("WhichKeyIconCyan", { fg = c.bright_cyan })
  hi("WhichKeyIconGreen", { fg = c.bright_green })
  hi("WhichKeyIconGrey", { fg = c.bright_black })
  hi("WhichKeyIconOrange", { fg = c.bright_yellow })
  hi("WhichKeyIconPurple", { fg = c.bright_magenta })
  hi("WhichKeyIconRed", { fg = c.bright_red })
  hi("WhichKeyIconYellow", { fg = c.bright_yellow })

  hi("TroubleNormal", { fg = c.fg, bg = c.bg })
  hi("TroubleNormalNC", { fg = c.fg, bg = c.bg })
  hi("TroubleText", { fg = c.fg })
  hi("TroubleCount", { fg = c.bright_magenta, bold = true })
  hi("TroubleIndent", { fg = c.bright_black })
  hi("TroubleFoldIcon", { fg = c.bright_blue })
  hi("TroubleLocation", { fg = c.bright_black })
  hi("TroubleSource", { fg = c.bright_cyan })
  hi("TroubleCode", { fg = c.bright_black })
  hi("TroublePreview", { bg = c.black })
  hi("TroubleError", { fg = c.bright_red })
  hi("TroubleWarning", { fg = c.bright_yellow })
  hi("TroubleInformation", { fg = c.bright_blue })
  hi("TroubleHint", { fg = c.bright_cyan })
  hi("TroubleSignError", { fg = c.bright_red })
  hi("TroubleSignWarning", { fg = c.bright_yellow })
  hi("TroubleSignInformation", { fg = c.bright_blue })
  hi("TroubleSignHint", { fg = c.bright_cyan })

  hi("MasonNormal", { fg = c.fg, bg = c.bg })
  hi("MasonHeader", { fg = c.cursor_text, bg = c.magenta, bold = true })
  hi("MasonHeaderSecondary", { fg = c.cursor_text, bg = c.bright_blue, bold = true })
  hi("MasonHighlight", { fg = c.bright_blue })
  hi("MasonHighlightBlock", { fg = c.cursor_text, bg = c.bright_blue })
  hi("MasonHighlightBlockBold", { fg = c.cursor_text, bg = c.bright_blue, bold = true })
  hi("MasonMuted", { fg = c.bright_black })
  hi("MasonMutedBlock", { fg = c.fg, bg = c.black })
  hi("MasonError", { fg = c.bright_red })
  hi("MasonWarning", { fg = c.bright_yellow })
  hi("MasonSuccess", { fg = c.bright_green })
  hi("MasonPending", { fg = c.bright_cyan })

  hi("LazyNormal", { fg = c.fg, bg = c.bg })
  hi("LazyButton", { fg = c.fg, bg = c.black })
  hi("LazyButtonActive", { fg = c.selection_fg, bg = c.selection_bg, bold = true })
  hi("LazyH1", { fg = c.cursor_text, bg = c.magenta, bold = true })
  hi("LazyH2", { fg = c.bright_magenta, bold = true })
  hi("LazySpecial", { fg = c.bright_cyan })
  hi("LazyProgressDone", { fg = c.bright_green })
  hi("LazyProgressTodo", { fg = c.bright_black })
  hi("LazyCommit", { fg = c.bright_green })
  hi("LazyCommitIssue", { fg = c.bright_yellow })
  hi("LazyCommitType", { fg = c.bright_blue })
  hi("LazyReasonPlugin", { fg = c.bright_magenta })
  hi("LazyReasonEvent", { fg = c.bright_yellow })
  hi("LazyReasonCmd", { fg = c.bright_cyan })
  hi("LazyReasonFt", { fg = c.bright_green })
  hi("LazyReasonKeys", { fg = c.bright_blue })

  hi("NoicePopup", { fg = c.fg, bg = c.bg })
  hi("NoicePopupBorder", { fg = c.bright_magenta, bg = c.bg })
  hi("NoicePopupTitle", { fg = c.fg, bg = c.magenta, bold = true })
  hi("NoiceSplit", { fg = c.fg, bg = c.bg })
  hi("NoiceSplitBorder", { fg = c.magenta, bg = c.bg })
  hi("NoiceCmdline", { fg = c.fg, bg = c.bg })
  hi("NoiceCmdlineIcon", { fg = c.bright_yellow, bg = c.bg })
  hi("NoiceCmdlineIconSearch", { fg = c.bright_cyan, bg = c.bg })
  hi("NoiceCmdlinePopup", { fg = c.fg, bg = c.bg })
  hi("NoiceCmdlinePopupBorder", { fg = c.bright_magenta, bg = c.bg })
  hi("NoiceCmdlinePopupTitle", { fg = c.fg, bg = c.magenta, bold = true })
  hi("NoiceCmdlinePopupBorderSearch", { fg = c.bright_cyan, bg = c.bg })
  hi("NoiceCmdlinePopupBorderHelp", { fg = c.bright_blue, bg = c.bg })
  hi("NoiceCmdlinePrompt", { fg = c.bright_yellow, bg = c.bg })
  hi("NoiceConfirm", { fg = c.fg, bg = c.bg })
  hi("NoiceConfirmBorder", { fg = c.bright_magenta, bg = c.bg })
  hi("NoiceConfirmDefaultChoice", { fg = c.cursor_text, bg = c.selection_bg, bold = true })
  hi("NoiceConfirmDefaultChoiceKey", { fg = c.bright_yellow, bg = c.selection_bg, bold = true })
  hi("NoiceVirtualText", { fg = c.bright_black })
  hi("NoiceFormatProgressTodo", { fg = c.bright_black, bg = c.black })
  hi("NoiceFormatProgressDone", { fg = c.fg, bg = c.magenta })
  hi("NoiceMini", { fg = c.fg, bg = c.black })
  hi("NoiceCursor", { fg = c.cursor_text, bg = c.cursor })

  set_groups({ "NotifyERRORBorder", "NotifyERRORIcon", "NotifyERRORTitle" }, { fg = c.bright_red })
  set_groups({ "NotifyWARNBorder", "NotifyWARNIcon", "NotifyWARNTitle" }, { fg = c.bright_yellow })
  set_groups({ "NotifyINFOBorder", "NotifyINFOIcon", "NotifyINFOTitle" }, { fg = c.bright_blue })
  set_groups({ "NotifyDEBUGBorder", "NotifyDEBUGIcon", "NotifyDEBUGTitle" }, { fg = c.bright_black })
  set_groups({ "NotifyTRACEBorder", "NotifyTRACEIcon", "NotifyTRACETitle" }, { fg = c.bright_magenta })
  hi("NotifyBackground", { fg = c.fg, bg = c.bg })
  hi("NotifyERRORBody", { fg = c.fg, bg = c.bg })
  hi("NotifyWARNBody", { fg = c.fg, bg = c.bg })
  hi("NotifyINFOBody", { fg = c.fg, bg = c.bg })
  hi("NotifyDEBUGBody", { fg = c.fg, bg = c.bg })
  hi("NotifyTRACEBody", { fg = c.fg, bg = c.bg })

  hi("FlashBackdrop", { fg = c.bright_black })
  hi("FlashLabel", { fg = c.cursor_text, bg = c.bright_yellow, bold = true })
  hi("FlashMatch", { fg = c.cursor_text, bg = c.bright_cyan, bold = true })
  hi("FlashCurrent", { fg = c.cursor_text, bg = c.bright_magenta, bold = true })
  hi("FlashPrompt", { fg = c.fg, bg = c.bg })
  hi("IlluminatedWordText", { bg = c.black })
  hi("IlluminatedWordRead", { bg = c.black })
  hi("IlluminatedWordWrite", { bg = c.black, bold = true })
  hi("IblIndent", { fg = c.black })
  hi("IblScope", { fg = c.magenta })
  hi("IndentBlanklineChar", { fg = c.black })
  hi("IndentBlanklineContextChar", { fg = c.magenta })
  hi("MiniIndentscopeSymbol", { fg = c.magenta })
  hi("MiniIconsAzure", { fg = c.bright_blue })
  hi("MiniIconsBlue", { fg = c.bright_blue })
  hi("MiniIconsCyan", { fg = c.bright_cyan })
  hi("MiniIconsGreen", { fg = c.bright_green })
  hi("MiniIconsGrey", { fg = c.bright_black })
  hi("MiniIconsOrange", { fg = c.bright_yellow })
  hi("MiniIconsPurple", { fg = c.bright_magenta })
  hi("MiniIconsRed", { fg = c.bright_red })
  hi("MiniIconsYellow", { fg = c.bright_yellow })
  hi("MiniStatuslineModeNormal", { fg = c.cursor_text, bg = c.bright_blue, bold = true })
  hi("MiniStatuslineModeInsert", { fg = c.cursor_text, bg = c.bright_green, bold = true })
  hi("MiniStatuslineModeVisual", { fg = c.cursor_text, bg = c.bright_magenta, bold = true })
  hi("MiniStatuslineModeReplace", { fg = c.cursor_text, bg = c.bright_red, bold = true })
  hi("MiniStatuslineModeCommand", { fg = c.cursor_text, bg = c.bright_yellow, bold = true })
  hi("MiniStatuslineModeOther", { fg = c.cursor_text, bg = c.cyan, bold = true })
  hi("DapBreakpoint", { fg = c.bright_red })
  hi("DapBreakpointCondition", { fg = c.bright_yellow })
  hi("DapLogPoint", { fg = c.bright_blue })
  hi("DapStoppedLine", { bg = c.black })
end

apply()

-- Reapply after LazyVim's lazy UI plugins initialize and when this scheme is
-- selected again from a colorscheme picker.
local group = vim.api.nvim_create_augroup("seafoam_colorscheme", { clear = true })
vim.api.nvim_create_autocmd({ "ColorScheme", "User" }, {
  group = group,
  pattern = { "seafoam", "VeryLazy" },
  callback = function()
    if vim.g.colors_name == "seafoam" then
      apply()
    end
  end,
})
