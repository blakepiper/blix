# Phone system composition, independent of the workstation profiles. OXWM is
# an explicit initial choice; a different phone environment can replace it.
# Architecture, boot, firmware and storage belong to the hardware layer.
{ lib, ... }:

{
  imports = [ ../modules/common ../modules/desktop ];

  home-manager.users.przvl.imports = [ ../home/przvl/phone.nix ];

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
}
