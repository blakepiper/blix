return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "minimal",
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local theme = {}
      for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal", "inactive" }) do
        theme[mode] = {
          a = { fg = "#e5e5e5", bg = "#303030", gui = "bold" },
          b = { fg = "#e5e5e5", bg = "#121212" },
          c = { fg = "#e5e5e5", bg = "#000000" },
        }
      end
      opts.options.theme = theme
      opts.options.component_separators = ""
      opts.options.section_separators = ""
    end,
  },
}
