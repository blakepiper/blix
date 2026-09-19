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
      if [[ $- == *i* && -z ''${BLE_SESSION_ID-} ]]; then
        source -- ${pkgs.blesh}/share/blesh/ble.sh --attach=none
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
