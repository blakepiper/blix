# An ordinary Blix desktop on portable phone hardware. Architecture, boot,
# firmware, storage and panel orientation belong to the host's hardware layer.
{ lib, ... }:

{
  imports = [ ../modules/common ];

  blix.machine = {
    type = lib.mkDefault "phone";
    hasBattery = lib.mkDefault true;
    hasBacklight = lib.mkDefault true;
    hasBluetooth = lib.mkDefault true;
  };

  # Keep sleep manual until suspend and Bluetooth wake have been verified.
  # A short power-button press locks; the control menu still offers shutdown.
  services.logind.settings.Login.HandlePowerKey = lib.mkDefault "lock";
  services.upower = {
    enable = lib.mkDefault true;
    ignoreLid = lib.mkDefault true;
    criticalPowerAction = lib.mkDefault "PowerOff";
    percentageAction = lib.mkDefault 3;
  };

  zramSwap.enable = lib.mkDefault true;
  nix.settings = {
    max-jobs = lib.mkDefault 1;
    cores = lib.mkDefault 2;
  };

  home-manager.users.przvl.blix.display.blankAfterSeconds = lib.mkDefault 300;
}
