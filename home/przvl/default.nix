{ pkgs, ... }:

let
  resources = import ./resources.nix { inherit pkgs; };
  nightMode = import ./scripts/night-mode.nix { inherit pkgs; };
  aiUsage = import ./scripts/ai-usage.nix {
    inherit pkgs;
    modelUsageSource = resources.modelUsageSource;
  };
in
{
  _module.args = {
    inherit resources nightMode aiUsage;
  };

  imports = [
    ./host.nix
    ./theme.nix
    ./packages.nix
    ./programs
    ./desktop
    ./services
  ];

  home = {
    username = "przvl";
    homeDirectory = "/home/przvl";
    stateVersion = "26.05";
  };

  programs.git.enable = true;
}
