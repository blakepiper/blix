# Manual X11/OXWM session selected by a profile.
{ pkgs, ... }:

{
  services.xserver = {
    enable = true;

    # Blix starts one X11 session manually from a TTY. The Home Manager
    # configuration supplies ~/.xinitrc, so NixOS only needs to install xinit
    # and expose OXWM as the available window manager.
    displayManager.startx = {
      enable = true;
      generateScript = false;
    };

    windowManager.oxwm = {
      enable = true;
      package = pkgs.oxwm;
    };
  };
}
