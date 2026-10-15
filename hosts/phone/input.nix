# Observed phone input devices; these rules are not imported by other hosts.
{ config, lib, ... }:

let
  rotation = config.home-manager.users.przvl.blix.display.primaryRotation;
  touchMatrix = {
    normal = "1 0 0 0 1 0 0 0 1";
    left = "0 -1 1 1 0 0 0 0 1";
    right = "0 1 0 -1 0 1 0 0 1";
    inverted = "-1 0 1 0 -1 1 0 0 1";
  }.${rotation};
in
{
  services.xserver.inputClassSections = lib.mkAfter [
    ''
      Identifier "Blix phone Bluetooth keyboard"
      MatchIsKeyboard "on"
      MatchProduct "Bluetooth Keyboard"
      Option "XkbLayout" "${config.services.xserver.xkb.layout}"
      Option "XkbOptions" "terminate:ctrl_alt_bksp,altwin:swap_lalt_lwin"
    ''
    ''
      Identifier "Blix phone touchscreen orientation"
      MatchIsTouchscreen "on"
      MatchProduct "Synaptics S3706B"
      Option "TransformationMatrix" "${touchMatrix}"
    ''
  ];
}
