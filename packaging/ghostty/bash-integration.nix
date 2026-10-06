# Backport https://github.com/ghostty-org/ghostty/pull/11644 to the pinned
# 1.3.1 integration script, without rebuilding the terminal executable.
{ ghostty, patch, runCommand }:

runCommand "ghostty-bash-integration" {
  nativeBuildInputs = [ patch ];
} ''
  mkdir -p "$out"
  cp -r ${ghostty.shell_integration}/. "$out/"
  chmod -R u+w "$out"
  cd "$out"
  patch -p1 < ${./ble-prompt.patch}
''
