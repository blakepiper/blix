{ config, lib, ... }:

{
  # This keyboard's Mac mode puts Cmd in the Alt position. Scope the swap to
  # its USB identity so the built-in keyboard keeps Win as Super. Xorg applies
  # this on every connection, without scraping device IDs from its log.
  services.xserver.inputClassSections = lib.mkAfter [
    ''
      Identifier "Blix mechanical keyboard"
      MatchIsKeyboard "on"
      MatchUSBID "1fc9:e8c7"
      Option "XkbLayout" "${config.services.xserver.xkb.layout}"
      Option "XkbOptions" "terminate:ctrl_alt_bksp,altwin:swap_alt_win"
    ''
  ];
}
