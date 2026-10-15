# OnePlus 6T (fajita): bootstrap boot verified 2026-10-14; full desktop pending.
{ ... }:

{
  imports = [
    ../../profiles/phone.nix
    ./hardware.nix
    ./bootstrap.nix
  ];

  networking.hostName = "phone";
  # The planned Bluetooth folding keyboard includes a touchpad.
  blix.machine.hasTouchpad = true;
  # New installation; existing hosts and the shared Home Manager state stay put.
  system.stateVersion = "26.11";
  home-manager.users.przvl = import ./home.nix;
}
