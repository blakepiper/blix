{ osConfig, ... }:

{
  imports = [ ./display.nix ./brightness.nix ./gpu.nix ];

  _module.args.oxwmExtraKeybindings = ''
    oxwm.key.bind({ mod }, "G", oxwm.spawn("${osConfig.programs.steam.package}/bin/steam"))
  '';
}
