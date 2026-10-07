{ pkgs, fixture }:

let
  host = fixture {
    profile = ../profiles/laptop.nix;
    system = pkgs.stdenv.hostPlatform.system;
  };
in
pkgs.runCommand "bar-async-checks" {
  nativeBuildInputs = [ pkgs.python3 ];
  FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
} ''
  python3 ${./bar-async.py} ${host.pkgs.oxwm}/bin/oxwm \
    ${pkgs.xvfb}/bin/Xvfb ${pkgs.xdotool}/bin/xdotool
  touch "$out"
''
