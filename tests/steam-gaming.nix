{ pkgs, mkHost }:
let
  desktop = mkHost { modules = [ ../hosts/desktop ]; };
in
pkgs.runCommand "steam-gaming-checks" {
  nativeBuildInputs = [ pkgs.python3 ];
  FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
} ''
  python3 ${./steam-gaming.py} ${desktop.pkgs.oxwm}/bin/oxwm \
    ${pkgs.xvfb}/bin/Xvfb ${pkgs.picom}/bin/picom ${pkgs.xdotool}/bin/xdotool \
    ${pkgs.libx11}/lib/libX11.so.6 ${../home/przvl/config/picom/picom.conf}
  touch "$out"
''
