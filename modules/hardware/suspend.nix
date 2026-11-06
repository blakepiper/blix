# Workstation sleep policy; the phone deliberately does not select this module.
{ lib, ... }:
{
  # Let firmware and the kernel choose s2idle or deep sleep for each device.
  powerManagement.enable = lib.mkDefault true;
  systemd.sleep.settings.Sleep.AllowSuspend = lib.mkDefault true;
}
