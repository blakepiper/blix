{ pkgs, ... }:

{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
    initExtra = ''
      if [[ $- == *i* ]] && ! declare -F ble-attach >/dev/null 2>&1; then
        source -- ${pkgs.blesh}/share/blesh/ble.sh --attach=none
        # TUI applications can leave queued focus reports on exit. They are
        # terminal notifications, not editing keys or visible-bell errors.
        ble-bind -m emacs -f focus nop
        ble-bind -m emacs -f blur nop
        ble-attach
      fi
      PS1='\u@\h:\w\$ '
    '';
  };

  home.file.".bash_profile".text = ''
    # Keep login shells and interactive shells on the same configuration.
    [[ ! -f ~/.bashrc ]] || . ~/.bashrc
  '';
}
