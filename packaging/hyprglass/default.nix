{ lib, fetchFromGitHub, mkHyprlandPlugin, wayland-scanner }:

mkHyprlandPlugin {
  pluginName = "hyprglass";
  version = "0-unstable-2026-11-15";

  # The release branch targets Hyprland 0.57; update alongside Hyprland.
  src = fetchFromGitHub {
    owner = "hyprnux";
    repo = "hyprglass";
    rev = "dc00c628623e5e504b363e26dd489ee766d2fa12";
    hash = "sha256-z1ICVfSHI+6MqG0eybXXGCtetwAaPj5yeRbJEzZCxGo=";
  };

  nativeBuildInputs = [ wayland-scanner ];
  makeFlags = [ "HYPRGLASS_VERSION=0.57-dc00c62" ];
  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 hyprglass.so $out/lib/libhyprglass.so
    runHook postInstall
  '';

  meta = {
    description = "Liquid glass material for Hyprland windows";
    homepage = "https://github.com/hyprnux/hyprglass";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
