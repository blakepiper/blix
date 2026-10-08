# Input policy for profiles selecting the X11 environment.
{ ... }:

{
  imports = [ ./keyboard.nix ./mouse.nix ./touchpad.nix ];
  services.libinput.enable = true;
}
