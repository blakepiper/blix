# Workstation user composition, shared by zen, t490 and the desktop profile.
{ pkgs, ... }:

{
  imports = [
    ./base.nix
    ./packages.nix
    ./appearance.nix
    ./programs
    ./programs/power.nix
    ./environments/oxwm.nix
    ./environments/labwc.nix
  ];

  home.packages = with pkgs; [ xfe mpv ];
}
