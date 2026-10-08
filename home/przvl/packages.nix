{ pkgs, ... }:

# Reusable command-line tools, selected independently by each user composition.
{
  home.packages = with pkgs; [
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
    cmatrix
    bubblewrap
    blesh
  ];
}
