{ pkgs, ... }:

let
  blix = import ./scripts/blix.nix { inherit pkgs; };
in
{
  _module.args = {
    inherit (blix)
      clipboardTextProbe
      hardwareHotplug
      lockService
      blixLock
      scripts
      xsecurelockWithoutPicom;
  };

  imports = [
    ./host.nix
    ./packages.nix
    ./appearance.nix
    ./programs
    ./x11.nix
    ./hyprland.nix
    ./services
  ];

  home = {
    username = "przvl";
    homeDirectory = "/home/przvl";
    stateVersion = "26.05";
  };

  programs.wiremix = {
    enable = true;
    # Distinguish outputs that share the same sound-card nickname.
    settings.names.endpoint = [
      "{node:node.nick}"
      "{node:node.description}"
      "{node:node.name}"
    ];
  };
}
