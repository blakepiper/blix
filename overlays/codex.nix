{ releases }:
final: prev:

let
  release = releases.${final.stdenv.hostPlatform.system};
  manifest = builtins.fromJSON (builtins.readFile "${release}/codex-package.json");
  version = manifest.version;
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
      cp -a "$src"/. "$out"/
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
