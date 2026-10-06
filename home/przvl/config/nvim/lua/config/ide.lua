if vim.env.NVIM_IDE ~= "1" then
  return
end

local group = vim.api.nvim_create_augroup("nvim_ide", { clear = true })
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

  local function terminal_width()
    return math.max(1, math.floor(vim.o.columns * 0.4 + 0.5))
  end

  local terminal_wins = {}
  local function resize_terminals()
    for _, terminal_win in pairs(terminal_wins) do
      if vim.api.nvim_win_is_valid(terminal_win) then
        vim.api.nvim_win_set_width(terminal_win, terminal_width())
      end
    end
  end

  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = resize_terminals,
  })

  local terminals_opened = false
  local function open_terminals()
    if terminals_opened then
      return
    end
    terminals_opened = true

    local function open_terminal(count)
      local terminal = snacks.terminal.open(nil, {
        cwd = root,
        count = count,
        start_insert = false,
        win = {
          position = "right",
          width = terminal_width(),
          stack = true,
          enter = false,
          on_win = function(win)
            terminal_wins[count] = win.win
            resize_terminals()
          end,
        },
      })

      if count == 2 and vim.env.NVIM_IDE_FETCH then
        vim.api.nvim_chan_send(
          vim.b[terminal.buf].terminal_job_id,
          vim.fn.shellescape(vim.env.NVIM_IDE_FETCH) .. "\n"
        )
      end
    end

    open_terminal(1)
    open_terminal(2)

    if vim.api.nvim_win_is_valid(editor_win) then
      vim.api.nvim_set_current_win(editor_win)
    end
  end

  local explorer = snacks.picker.get({ source = "explorer" })[1]
  if not explorer then
    explorer = snacks.explorer({
      cwd = root,
      enter = false,
      -- Start the initial search explicitly so terminals wait for completion.
      find = false,
      layout = {
        preset = "sidebar",
        preview = false,
        layout = {
          position = "left",
          width = 30,
          min_width = 30,
        },
      },
    })
  else
    explorer:set_cwd(root)
  end

  if explorer then
    -- Snacks refreshes from Git status, file following and filesystem events.
    -- Let the current finder AND matcher finish before starting another pass;
    -- aborting a coroutine does not stop it synchronously in this version.
    if not explorer._ide_serialized_find then
      explorer._ide_serialized_find = true
      local find = explorer.find
      local pending = false
      local waiting = false
      local callbacks = {}

      local function flush()
        if explorer.closed then
          pending = false
          callbacks = {}
          waiting = false
          return
        end
        if explorer:is_active() then
          vim.defer_fn(flush, 10)
          return
        end
        waiting = false
        if not pending then
          return
        end
        pending = false
        local done = callbacks
        callbacks = {}
        find(explorer, {
          on_done = function()
            for _, callback in ipairs(done) do
              callback()
            end
          end,
        })
      end

      explorer.find = function(self, opts)
        if self.closed then
          return
        end
        if self:is_active() or waiting then
          pending = true
          if opts and opts.on_done then
            callbacks[#callbacks + 1] = opts.on_done
          end
          if not waiting then
            waiting = true
            vim.defer_fn(flush, 10)
          end
          return
        end
        return find(self, opts)
      end
    end
    explorer:find({
      on_done = function()
        vim.schedule(function()
          if not explorer.closed then
            open_terminals()
          end
        end)
      end,
    })
  else
    open_terminals()
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
