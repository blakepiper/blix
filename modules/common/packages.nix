{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    openssh
    tree-sitter
    gnutar
    gzip
    shellcheck
    pciutils
    psmisc
  ];

  environment.pathsToLink = [ "/share/bash-completion" ];
}
