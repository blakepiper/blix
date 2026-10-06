{ pkgs, fixture }:

let
  host = fixture {
    profile = ../profiles/laptop.nix;
    system = pkgs.stdenv.hostPlatform.system;
  };
  config = host.config.home-manager.users.przvl.home.file.".config/oxwm/config.lua".source;
in
pkgs.runCommand "bar-slider-checks" {
  nativeBuildInputs = [ pkgs.python3 ];
  FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
} ''
  python3 ${./bar-sliders.py} ${host.pkgs.oxwm}/bin/oxwm ${config} \
    ${pkgs.libx11}/lib/libX11.so.6 ${pkgs.xvfb}/bin/Xvfb ${pkgs.xdotool}/bin/xdotool
  touch "$out"
''
