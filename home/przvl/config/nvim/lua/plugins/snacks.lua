return {
  {
    "folke/snacks.nvim",
    opts = {
      -- Keep the explorer explicitly enabled for the nvimide startup layout.
      explorer = {},
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
