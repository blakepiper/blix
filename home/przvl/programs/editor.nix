{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    withPython3 = false;
    withRuby = false;
    withNodeJs = false;

    # mini.base16 derives every highlight group from the sixteen colors the
    # active theme exports, so Neovim follows the rest of the desktop.
    plugins = [ pkgs.vimPlugins.mini-nvim ];

    initLua = ''
      vim.o.termguicolors = true

      -- Never let a missing or malformed theme stop Neovim from starting.
      local ok, palette = pcall(dofile, "${config.blix.currentThemeDir}/base16.lua")
      if ok and type(palette) == "table" then
        pcall(function()
          require("mini.base16").setup({ palette = palette, use_cterm = true })
        end)
      end
    '';
  };
}
