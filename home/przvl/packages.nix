{ pkgs, scripts, ... }:

# User-facing packages from Blix. Xorg, OXWM, and the audio stack are
# installed by the NixOS modules; the rest follows the same small X11 set.
{
  home.packages = with pkgs; [
    pkgs."st-blix"
    xfe
    dmenu
    mpv
    feh
    ripgrep
    fd
    fzf
    curl
    jq
    bat
    eza
    lazygit
    less
    man
    unzip
    bash-completion
    codex
    maim
    slop
    xclip
    clipmenu
    xsecurelock
    xss-lock
    picom
    playerctl
    brightnessctl
    blesh
  ] ++ scripts;
}
