# Optional Wayland session, selected alongside X11 by workstation profiles.
{ ... }:
{
  programs.labwc.enable = true;
  security.pam.services.gtklock = { };
}
