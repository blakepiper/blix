return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          projects = {
            -- No ~/dev or ~/projects here, so scan home itself.
            -- Finds repository roots below ~.
            dev = { "~" },
          },
        },
      },
    },
  },
}
