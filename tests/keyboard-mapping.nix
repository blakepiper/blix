# Compile the actual global and device-specific layouts without an X server.
{ pkgs, fixture }:

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
in
pkgs.runCommand "keyboard-mapping-checks" {
  nativeBuildInputs = [ pkgs.python3 pkgs.libxkbcommon ];
} ''
  python3 ${./keyboard-mapping.py} ${settings}
  touch "$out"
''
