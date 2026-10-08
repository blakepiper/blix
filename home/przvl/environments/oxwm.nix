# Reusable OXWM session machinery; applications are selected by each user root.
{ config, lib, pkgs, ... }:

let
  blix = import ../scripts/blix.nix {
    inherit lib pkgs;
    inherit (config.blix.hardware) hasBattery hasBacklight;
  };
in
{
  _module.args = {
    inherit (blix)
      clipboardTextProbe
      lockService
      blixLock
      oxwmVolume
      oxwmBrightness
      scripts
      xsecurelockWithoutPicom;
  };

  imports = [
    ../hardware/bluetooth.nix
    ../hardware/display.nix
    ../programs/settings.nix
    ../x11.nix
    ../services
  ];

  home.packages = with pkgs; [
    dmenu
    feh
    maim
    slop
    xclip
    clipmenu
    xsecurelock
    xss-lock
    picom
    playerctl
    gammastep
  ] ++ lib.optional config.blix.hardware.hasBacklight brightnessctl ++ blix.scripts;
}
