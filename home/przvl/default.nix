{ pkgs, ... }:

let
  theme = import ./theme.nix;
  resources = import ./resources.nix { inherit pkgs; };
  nightMode = import ./scripts/night-mode.nix { inherit pkgs; };
  aiUsage = import ./scripts/ai-usage.nix {
    inherit pkgs;
    modelUsageSource = resources.modelUsageSource;
  };
in
{
  _module.args = {
    inherit theme resources nightMode aiUsage;
  };

  imports = [
    ./host.nix
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
}
