{ ... }:

{
  services.power-profiles-daemon.enable = true;

  # Suspend on lid close, but keep running while docked to an external
  # display.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };
}
