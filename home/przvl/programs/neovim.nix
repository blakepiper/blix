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

      export BLIX_NVIMIDE=1
      exec nvim "$@"
    '';
  };

in
{
  # The complete editor configuration is installed by x11.nix. Keep Neovim
  # as a plain package here so Home Manager does not generate a competing
  # init.lua beside the managed configuration directory.
  home.packages = [
    pkgs.neovim
    nvimide
  ];
}
