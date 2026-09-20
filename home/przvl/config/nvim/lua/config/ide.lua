if vim.env.BLIX_NVIMIDE ~= "1" then
  return
end

local group = vim.api.nvim_create_augroup("blix_nvimide", { clear = true })
local started = false
local scheduled = false

local function project_root()
  local lazyvim = rawget(_G, "LazyVim")
  if lazyvim and lazyvim.root then
    local ok, root = pcall(lazyvim.root)
    if ok and type(root) == "string" and root ~= "" then
      return root
    end
  end

  return vim.fn.getcwd()
end

local function prepare_editor_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)

  if vim.bo[buf].filetype == "snacks_dashboard" or (name ~= "" and vim.fn.isdirectory(name) == 1) then
    vim.cmd("enew")
  end
end

local function start()
  if started then
    return
  end
  started = true

  local ok, snacks = pcall(require, "snacks")
  if not ok then
    vim.notify("nvimide could not load snacks.nvim: " .. snacks, vim.log.levels.ERROR)
    return
  end

  local editor_win = vim.api.nvim_get_current_win()
  local root = project_root()
  prepare_editor_buffer()

  local terminal_opened = false
  local function open_terminal()
    if terminal_opened then
      return
    end
    terminal_opened = true

    snacks.terminal.open(nil, {
      cwd = root,
      start_insert = false,
      win = {
        position = "bottom",
        height = 0.4,
        enter = false,
      },
    })

    if vim.api.nvim_win_is_valid(editor_win) then
      vim.api.nvim_set_current_win(editor_win)
    end
  end

  local explorer = snacks.explorer({
    cwd = root,
    enter = false,
    layout = {
      preset = "sidebar",
      preview = false,
      layout = {
        position = "left",
        width = 30,
        min_width = 30,
      },
    },
    on_show = function()
      vim.schedule(open_terminal)
    end,
  })

  if not explorer then
    open_terminal()
  end
end

local function schedule_start()
  if started or scheduled then
    return
  end
  scheduled = true
  vim.defer_fn(function()
    scheduled = false
    start()
  end, 50)
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  once = true,
  callback = schedule_start,
})

vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "VeryLazy",
  once = true,
  callback = schedule_start,
})

schedule_start()
