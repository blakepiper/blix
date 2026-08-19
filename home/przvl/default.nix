{ pkgs, ... }:

{
home.username = "przvl";
home.homeDirectory = "/home/przvl";
home.stateVersion = "26.05";
programs.git.enable = true;
home.packages = with pkgs; [
ripgrep
fd
];
}
