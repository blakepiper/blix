# Workstation suspend entry point shared by OXWM and labwc; not selected by phone.
{ lib, pkgs, ... }:
let
  suspend = pkgs.writeShellApplication {
    name = "blix-suspend";
    runtimeInputs = [ pkgs.systemd pkgs.jq pkgs.libnotify ];
    text = builtins.readFile ../config/blix-bin/blix-suspend;
  };
in
{
  options.blix.power.suspendCommand = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    description = "Store path of the workstation suspend command.";
  };
  config = {
    blix.power.suspendCommand = "${suspend}/bin/blix-suspend";
    home.packages = [ suspend ];
    xdg.dataFile."applications/blix-suspend.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Suspend
      Comment=Lock the desktop and suspend to memory
      Exec=${suspend}/bin/blix-suspend
      Icon=system-suspend
      Terminal=false
      Categories=System;
    '';
  };
}
