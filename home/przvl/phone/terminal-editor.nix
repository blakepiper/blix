# Small-screen overrides selected only by the phone user composition.
{ lib, pkgs, ... }:

{
  # At the phone's 192 DPI, 22 pt leaves only a 66x12 terminal grid.
  programs.ghostty.settings.font-size = lib.mkForce 12;

  # Derive a phone variant without changing the workstation's captured config.
  home.file.".config/nvim".source = lib.mkForce (pkgs.runCommand "nvim-phone-config" { } ''
    cp -r ${../config/nvim} "$out"
    chmod u+w "$out/lua/config" "$out/lua/plugins" "$out/lua/config/options.lua"
    cp --remove-destination ${./nvim-ide.lua} "$out/lua/config/ide.lua"
    cat ${./nvim-options.lua} >> "$out/lua/config/options.lua"
    cp ${./nvim-ui.lua} "$out/lua/plugins/phone.lua"
  '');
}
