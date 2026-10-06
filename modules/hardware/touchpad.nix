{ config, lib, ... }:

{
  # External USB/Bluetooth touchpads also scroll naturally on desktops and
  # phones. The capability selects the additional click/tap defaults.
  services.libinput.touchpad = {
    naturalScrolling = lib.mkDefault true;
  } // lib.optionalAttrs config.blix.machine.hasTouchpad {
    clickMethod = lib.mkDefault "clickfinger";
    tapping = lib.mkDefault true;
    tappingButtonMap = lib.mkDefault "lrm";
    disableWhileTyping = lib.mkDefault true;
  };
}
