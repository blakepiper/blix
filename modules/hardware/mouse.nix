{ lib, ... }:

{
  # Touchpads, tablets and pointing sticks are excluded. Keep this after the
  # generic libinput mouse section so its defaults cannot reset the option.
  services.xserver.inputClassSections = lib.mkAfter [
    ''
      Identifier "Blix mice (not pointing sticks)"
      MatchIsPointer "on"
      MatchIsTouchpad "off"
      MatchDriver "libinput"
      MatchTag "blix-mouse"
      Option "NaturalScrolling" "true"
    ''
  ];

  services.udev.extraRules = ''
    ACTION!="remove", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_MOUSE}=="1", ENV{ID_INPUT_POINTINGSTICK}!="1", ENV{ID_INPUT_TOUCHPAD}!="1", ENV{ID_INPUT_TABLET}!="1", ENV{ID_INPUT.tags}="$env{ID_INPUT.tags},blix-mouse"
  '';
}
