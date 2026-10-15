# OnePlus 6T (fajita): native boot and accelerated OXWM verified 2026-10-15.
{ ... }:

{
  imports = [
    ../../profiles/phone.nix
    ./hardware.nix
    ./bootstrap.nix
    ./input.nix
    ./audio.nix
  ];

  networking.hostName = "phone";
  # The paired Bluetooth folding keyboard includes a touchpad.
  blix.machine.hasTouchpad = true;
  services.getty = {
    autologinUser = "przvl";
    autologinOnce = false;
  };
  # New installation; existing hosts and the shared Home Manager state stay put.
  system.stateVersion = "26.11";
  home-manager.users.przvl = import ./home.nix;
}
