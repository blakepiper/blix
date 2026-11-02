{ pkgs, mkHost }:
let
  desktop = mkHost { modules = [ ../hosts/desktop ]; };
  zen = mkHost { modules = [ ../hosts/zen ]; };
  steamConfigured = host:
    let
      c = host.config;
      launcher = builtins.readFile c.home-manager.users.przvl.home.file.".config/oxwm/config.lua".source;
    in
      c.programs.steam.enable
      && c.hardware.graphics.enable32Bit
      && pkgs.lib.hasInfix
        (builtins.unsafeDiscardStringContext
          ''oxwm.key.bind({ mod }, "G", oxwm.spawn("${c.programs.steam.package}/bin/steam"))'')
        launcher;
in
assert steamConfigured desktop;
assert steamConfigured zen;
pkgs.runCommand "steam-gaming-checks" {
  nativeBuildInputs = [ pkgs.python3 ];
  FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
} ''
  python3 ${./steam-gaming.py} ${desktop.pkgs.oxwm}/bin/oxwm \
    ${pkgs.xvfb}/bin/Xvfb ${pkgs.picom}/bin/picom ${pkgs.xdotool}/bin/xdotool \
    ${pkgs.libx11}/lib/libX11.so.6 ${../home/przvl/config/picom/picom.conf}
  touch "$out"
''
