{ pkgs, ... }:

let
  nvimide = pkgs.writeShellApplication {
    name = "nvimide";
    runtimeInputs = [ pkgs.neovim ];
    text = ''
      if [[ $# -gt 0 && -d $1 ]]; then
        cd -- "$1"
        shift
      fi

      export NVIM_IDE=1
      export NVIM_IDE_FETCH=${pkgs.neofetch}/bin/neofetch
      exec nvim "$@"
    '';
  };

in
{
  # Keep the captured init.lua; generate only the Nix-specific tool adapter.
  home.packages = with pkgs; [
    neovim
    lua-language-server
    stylua
    shfmt
    nvimide
  ];

  home.file.".config/nvim" = {
    source = ../config/nvim;
    recursive = true;
  };

  # Mason's downloaded binaries are not NixOS packages. Supply the default
  # LazyVim language server and formatters through the system closure instead.
  home.file.".config/nvim/lua/plugins/nix.lua".text = ''
    return {
      { "mason-org/mason.nvim", enabled = false },
      { "mason-org/mason-lspconfig.nvim", enabled = false },
      {
        "neovim/nvim-lspconfig",
        opts = {
          servers = {
            lua_ls = {
              mason = false,
              cmd = { "${pkgs.lua-language-server}/bin/lua-language-server" },
            },
          },
        },
      },
      {
        "stevearc/conform.nvim",
        opts = {
          formatters = {
            stylua = { command = "${pkgs.stylua}/bin/stylua" },
            shfmt = { command = "${pkgs.shfmt}/bin/shfmt" },
          },
        },
      },
    }
  '';
}
