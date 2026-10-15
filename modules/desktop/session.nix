# X11/OXWM startx session selected by a profile.
{ pkgs, ... }:

{
  services.xserver = {
    enable = true;

    # Blix starts one X11 session from a local TTY. Host login policy chooses
    # when to invoke startx. Home Manager supplies ~/.xinitrc; NixOS installs
    # xinit and exposes OXWM as the available window manager.
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
