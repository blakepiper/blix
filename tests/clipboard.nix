{ pkgs, fixture }:

let
  host = fixture {
    profile = ../profiles/desktop.nix;
    system = pkgs.stdenv.hostPlatform.system;
  };
  daemon = builtins.head host.config.home-manager.users.przvl.systemd.user.services.blix-clipboard.Service.ExecStart;
in
pkgs.runCommand "clipboard-checks" {
  nativeBuildInputs = [ pkgs.python3 pkgs.xorg-server pkgs.xclip ];
} ''
  python3 ${./clipboard.py} ${daemon}
  touch "$out"
''
