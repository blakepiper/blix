{ ... }:

{
  imports = [
    ./bluetooth.nix
    ./keyboard.nix
    ./mouse.nix
    ./power.nix
    ./touchpad.nix
  ];

  services.libinput.enable = true;
}
