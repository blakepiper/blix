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
  programs.ghostty.settings.font-size = lib.mkForce 22;
  # Home Manager's generated .bash_profile sources .profile. Its source takes
  # precedence over home.file text, so use the supported login-shell hook.
  # SSH, other VTs and terminal windows keep their ordinary shells.
  programs.bash.profileExtra = lib.mkAfter ''
    if [[ -z ''${DISPLAY:-} && "$(${pkgs.coreutils}/bin/tty)" == /dev/tty1 ]]; then
      exec ${pkgs.xinit}/bin/startx -- :0 vt1 -keeptty
    fi
  '';
  blix.display.blankAfterSeconds = lib.mkDefault 300;
}
