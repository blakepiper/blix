{ releases }:
final: prev:

let
  release = releases.${final.stdenv.hostPlatform.system};
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  inputName = "codex-${final.stdenv.hostPlatform.parsed.cpu.name}";
  url = lock.nodes.${lock.nodes.${lock.root}.inputs.${inputName}}.locked.url;
  version = builtins.head (builtins.match ".*/rust-v([0-9]+\\.[0-9]+\\.[0-9]+)/.*" url);
in
{
  # Keep the complete official layout: the daemon copies this tree at startup.
  codex = final.stdenvNoCC.mkDerivation {
    pname = "codex";
    inherit version;
    src = release.outPath;
    dontUnpack = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      tar -xzf "$src" -C "$out"
      test -x "$out/bin/codex"
      test -f "$out/codex-package.json"
      test -x "$out/codex-path/rg"
      test -x "$out/codex-resources/bwrap"
      runHook postInstall
    '';
    meta = {
      description = "OpenAI Codex official stable release bundle";
      homepage = "https://github.com/openai/codex";
      license = final.lib.licenses.asl20;
      platforms = builtins.attrNames releases;
      mainProgram = "codex";
    };
  };
}
