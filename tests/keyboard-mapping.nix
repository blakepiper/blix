# Compile the actual global and device-specific layouts without an X server.
{ pkgs, fixture, phone }:

let
  host = fixture {
    profile = ../profiles/laptop.nix;
    system = pkgs.stdenv.hostPlatform.system;
  };
  cfg = host.config.services.xserver;
  settings = pkgs.writeText "blix-keyboard-settings.json" (builtins.toJSON {
    inherit (cfg) inputClassSections;
    inherit (cfg.xkb) layout model variant options;
  });
  phoneCfg = phone.config.services.xserver;
  phoneSettings = pkgs.writeText "blix-phone-keyboard-settings.json" (builtins.toJSON {
    inherit (phoneCfg) inputClassSections;
    inherit (phoneCfg.xkb) layout model variant options;
  });
in
pkgs.runCommand "keyboard-mapping-checks" {
  nativeBuildInputs = [ pkgs.python3 pkgs.libxkbcommon ];
} ''
  python3 ${./keyboard-mapping.py} ${settings} ${phoneSettings}
  touch "$out"
''
