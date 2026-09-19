{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    openssh
    xdg-utils
    xauth
    xset
    xsetroot
    setxkbmap
    xkbcomp
    xrandr
    xprop
    xdpyinfo
    tree-sitter
    gnutar
    gzip
    shellcheck
    mesa-demos
    pciutils
    psmisc
  ];

  environment.pathsToLink = [ "/share/bash-completion" ];
}
