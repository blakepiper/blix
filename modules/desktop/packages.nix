{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    xdg-utils
    xauth
    xset
    xsetroot
    setxkbmap
    xkbcomp
    xrandr
    xprop
    xdpyinfo
    mesa-demos
  ];
}
