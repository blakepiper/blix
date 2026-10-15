# Phone user composition. Choose applications and session modules here without
# inheriting the workstation's application list or future workstation changes.
{ lib, pkgs, ... }:

{
  imports = [
    ./base.nix
    ./packages.nix
    ./appearance.nix
    ./programs/shell.nix
    ./programs/browser.nix
    ./programs/btop.nix
    ./programs/git.nix
    ./programs/terminal.nix
    ./programs/neovim.nix
    ./programs/tmux.nix
    ./programs/neofetch.nix
    ./programs/audio.nix
    ./environments/oxwm.nix
  ];

  home.packages = with pkgs; [ xfe mpv ];
  # First-install pulls must work before this device has GitHub SSH credentials.
  programs.git.settings.url."git@github.com:".insteadOf = lib.mkForce [ ];
  blix.display.blankAfterSeconds = lib.mkDefault 300;
}
