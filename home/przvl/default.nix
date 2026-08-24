{ pkgs, ... }:

let
  theme = import ./theme.nix;
  resources = import ./resources.nix { inherit pkgs; };
  nightMode = import ./scripts/night-mode.nix { inherit pkgs; };
  sessionSwitcher = import ./scripts/session-switcher.nix { inherit pkgs; };
  aiUsage = import ./scripts/ai-usage.nix { inherit pkgs; };
in
{
  _module.args = {
    inherit theme resources nightMode sessionSwitcher aiUsage;
  };

  imports = [
    ./host.nix
    ./themes
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
