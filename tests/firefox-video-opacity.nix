{ pkgs, fixture }:

let
  host = fixture {
    profile = ../profiles/laptop.nix;
    system = pkgs.stdenv.hostPlatform.system;
  };
  firefox = host.config.home-manager.users.przvl.programs.firefox.finalPackage;
in
pkgs.runCommand "firefox-video-opacity-checks" {
  nativeBuildInputs = [ pkgs.python3 ];
  FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
} ''
  python3 ${./firefox-video-opacity.py} ${firefox}/bin/firefox \
    ${pkgs.geckodriver}/bin/geckodriver ${pkgs.ffmpeg-headless}/bin/ffmpeg \
    ${pkgs.xvfb}/bin/Xvfb ${pkgs.picom}/bin/picom \
    ${../home/przvl/config/picom/picom.conf} ${pkgs.libx11}/lib/libX11.so.6
  touch "$out"
''
