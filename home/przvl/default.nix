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
    ./services
  ];

  home = {
    username = "przvl";
    homeDirectory = "/home/przvl";
    stateVersion = "26.05";
  };
}
