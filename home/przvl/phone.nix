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
    ./phone/terminal-editor.nix
    ./phone/topbar.nix
  ];

  home.packages = with pkgs; [ xfe mpv ];
  # Suppress connection/disconnection popups while keeping the pairing agent.
  dconf.settings."org/blueman/general".plugin-list = [ "!ConnectionNotifier" ];
  # First-install pulls must work before this device has GitHub SSH credentials.
  programs.git.settings.url."git@github.com:".insteadOf = lib.mkForce [ ];
  # The folding keyboard reports its touch surface as a wheel mouse, so it
  # cannot produce native touchpad swipe gestures. Use horizontal wheel events
  # for Firefox history navigation; vertical wheel events still scroll pages.
  programs.firefox.profiles.default.settings."mousewheel.default.action.override_x" = 2;
  # Home Manager's generated .bash_profile sources .profile. Its source takes
  # precedence over home.file text, so use the supported login-shell hook.
  # SSH, other VTs and terminal windows keep their ordinary shells.
  programs.bash.profileExtra = lib.mkAfter ''
    if [[ -z ''${DISPLAY:-} && "$(${pkgs.coreutils}/bin/tty)" == /dev/tty1 ]]; then
      # Explicit server arguments skip NixOS's xserverrc and its custom XKB path.
      exec ${pkgs.xinit}/bin/startx -- :0 vt1 -keeptty -xkbdir /etc/X11/xkb
    fi
  '';
  # Keep the display awake; manual lock/suspend and monitor-off still work.
  blix.display.blankAfterSeconds = lib.mkDefault 0;
}
