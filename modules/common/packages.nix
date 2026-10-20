{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    openssh
    python315
    tree-sitter
    gnutar
    gzip
    shellcheck
    pciutils
    psmisc
    tailscale
  ];

  environment.pathsToLink = [ "/share/bash-completion" ];
}
