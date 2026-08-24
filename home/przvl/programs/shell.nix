{ pkgs, ... }:

{
  programs.bash = {
    enable = true;
    initExtra = ''
      if [[ $- == *i* && -z ''${BLE_SESSION_ID-} ]]; then
        source -- ${pkgs.blesh}/share/blesh/ble.sh --attach=none
        ble-attach
      fi
    '';
  };
}
