{ pkgs }:
pkgs.runCommand "workstation-suspend-checks" {
  nativeBuildInputs = [ pkgs.python3 pkgs.bash pkgs.jq ];
} ''
  python3 ${./suspend.py} ${../home/przvl/config/blix-bin/blix-suspend}
  touch "$out"
''
