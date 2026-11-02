# Launcher for hosts that select the NixOS Steam module.
{ osConfig, ... }:

{
  _module.args.oxwmExtraKeybindings = ''
    oxwm.key.bind({ mod }, "G", oxwm.spawn("${osConfig.programs.steam.package}/bin/steam"))
  '';
}
