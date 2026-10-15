return {
  { "akinsho/bufferline.nvim", enabled = false },
  {
    "folke/noice.nvim",
    opts = {
      cmdline = { view = "cmdline" },
      presets = { command_palette = false },
    },
  },
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = { enabled = false },
      terminal = { win = { position = "bottom", height = 0.25 } },
      picker = {
        layout = { preset = "ivy", preview = false },
        sources = {
          explorer = {
            layout = {
              preset = "sidebar",
              preview = false,
              layout = { position = "left", width = 22, min_width = 18 },
            },
          },
        },
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections = {
        lualine_a = { "mode" },
        lualine_b = {},
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {},
        lualine_y = { "progress" },
        lualine_z = { "location" },
      }
    end,
  },
}
