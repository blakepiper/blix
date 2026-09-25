final: prev:

{
  # codex-nix currently installs only the two executables. Since 0.157.0,
  # normal CLI startup also needs a complete package to seed the daemon.
  # Keep the upstream version and binary hashes, and supply the missing layout.
  codex = prev.codex.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      if [ ! -f "$out/codex-package.json" ]; then
        mkdir -p "$out/codex-path" "$out/codex-resources"
        # The daemon copies this tree and rejects links outside it. Static
        # helpers also survive GC after the original system generation expires.
        install -m755 ${final.pkgsStatic.ripgrep}/bin/rg "$out/codex-path/rg"
        install -m755 ${final.pkgsStatic.bubblewrap}/bin/bwrap "$out/codex-resources/bwrap"
        cat > "$out/codex-package.json" <<'JSON'
      ${builtins.toJSON {
        layoutVersion = 1;
        version = old.version;
        target = "${final.stdenv.hostPlatform.parsed.cpu.name}-unknown-linux-musl";
        variant = "codex";
        entrypoint = "bin/codex";
        resourcesDir = "codex-resources";
        pathDir = "codex-path";
      }}
      JSON
      fi
    '';
  });
}
