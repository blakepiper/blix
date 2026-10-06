{ config, lib, pkgs, scripts, ... }:

# User-facing packages from Blix. Xorg, OXWM, and the audio stack are
# installed by the NixOS modules; the rest follows the same small X11 set.
{
  home.packages = with pkgs; [
    xfe
    dmenu
    mpv
    feh
    ripgrep
    fd
    fzf
    curl
    gcc
    jq
    bat
    eza
    lazygit
    less
    man
    unzip
    bash-completion
    codex
    bubblewrap
    maim
    slop
    xclip
    clipmenu
    xsecurelock
    xss-lock
    picom
    playerctl
    gammastep
    blesh
  ] ++ lib.optional config.blix.hardware.hasBacklight brightnessctl ++ scripts;
}
