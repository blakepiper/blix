# Launcher for hosts that select the NixOS Steam module.
{ osConfig, pkgs, ... }:

{
  # Retain upstream translations, URL handling and library actions, but classify
  # the client as a game launcher rather than a network/file-transfer tool.
  xdg.dataFile."applications/steam.desktop".source = pkgs.runCommand "blix-steam.desktop" {
    nativeBuildInputs = [ pkgs.gnused pkgs.desktop-file-utils ];
  } ''
    sed -e 's/^Categories=.*/Categories=Game;/' \
      -e 's|^Exec=steam|Exec=${osConfig.programs.steam.package}/bin/steam|' \
      ${pkgs.steam-unwrapped}/share/applications/steam.desktop > "$out"
    desktop-file-validate "$out"
  '';
  _module.args.oxwmExtraKeybindings = ''
    oxwm.key.bind({ mod }, "G", oxwm.spawn("${osConfig.programs.steam.package}/bin/steam"))
  '';
}
