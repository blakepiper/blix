# Optional Wayland compositor for workstation profiles; launched manually from a TTY.
{ ... }:
{
  programs.hyprland.enable = true;
  security.pam.services.hyprlock = { };
}
