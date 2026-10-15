-- Use the terminal's real grid; never force Neovim's columns or lines.
if vim.env.NVIM_IDE ~= "1" then
  return
end

vim.defer_fn(function()
  local snacks = require("snacks")
  local editor = vim.api.nvim_get_current_win()
  local root = LazyVim.root()
  local terminal, explorer

  -- Keep a useful editing area in small windows. Both panes remain available
  -- through the ordinary <leader>e and Ctrl-/ toggles when not opened here.
  if vim.o.lines >= 22 then
    terminal = snacks.terminal.open(nil, {
      cwd = root,
      count = 1,
      start_insert = false,
      win = { position = "bottom", height = 0.25, enter = false },
    })
  end
  if vim.o.columns >= 100 then
    explorer = snacks.explorer({ cwd = root, enter = false })
  end

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("phone_ide_layout", { clear = true }),
    callback = function()
      if vim.o.columns < 100 and explorer and not explorer.closed then
        explorer:close()
      end
      if vim.o.lines < 22 and terminal then
        terminal:hide()
      end
    end,
  })

  if vim.api.nvim_win_is_valid(editor) then
    vim.api.nvim_set_current_win(editor)
  end
end, 50)
