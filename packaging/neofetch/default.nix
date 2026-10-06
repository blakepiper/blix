# Preserve Neofetch's NixOS compatibility fixes from the former nixpkgs package.
{ lib, stdenvNoCC, fetchFromGitHub, fetchpatch, bash, makeWrapper,
  coreutils, gawk, gnugrep, gnused, ncurses, pciutils, procps,
  util-linux, xdpyinfo, xprop, xrandr }:

stdenvNoCC.mkDerivation {
  pname = "neofetch";
  version = "7.1.0-unstable-2021-12-10";

  src = fetchFromGitHub {
    owner = "dylanaraps";
    repo = "neofetch";
    rev = "ccd5d9f52609bbdcd5d8fa78c4fdb0f12954125f";
    hash = "sha256-9MoX6ykqvd2iB0VrZCfhSyhtztMpBTukeKejfAWYW1w=";
  };

  patches = [
    (fetchpatch {
      name = "preserve-gio-extra-modules.patch";
      url = "https://github.com/dylanaraps/neofetch/commit/413c32e55dc16f0360f8e84af2b59fe45505f81b.patch";
      hash = "sha256-8Eamexxvr7wQkVouQWxehCtSljjxucP3kMCl89NrV7k=";
    })
    (fetchpatch {
      name = "update-nixos-logo.patch";
      url = "https://github.com/dylanaraps/neofetch/commit/c4eb4ec7783bb94cca0dbdc96db45a4d965956d2.patch";
      hash = "sha256-F6Q4dUtfmR28VxLbITiLFJ44FjG4T1Cvuz3a0nLisMs=";
    })
    (fetchpatch {
      name = "detect-nixos-version.patch";
      url = "https://github.com/dylanaraps/neofetch/commit/de253afcf41bab441dc58d34cae654040cab7451.patch";
      hash = "sha256-3i7WnCWNfsRjbenTULmKHft5o/o176imzforNmuoJwo=";
    })
  ];

  outputs = [ "out" "man" ];
  strictDeps = true;
  buildInputs = [ bash ];
  nativeBuildInputs = [ makeWrapper ];
  postPatch = ''patchShebangs --host neofetch'';
  makeFlags = [
    "PREFIX=${placeholder "out"}"
    "SYSCONFDIR=${placeholder "out"}/etc"
  ];
  postInstall = ''
    wrapProgram "$out/bin/neofetch" --prefix PATH : ${lib.makeBinPath [
      coreutils gawk gnugrep gnused ncurses pciutils procps
      util-linux xdpyinfo xprop xrandr
    ]}
    install -Dm644 LICENSE.md "$out/share/doc/neofetch/LICENSE.md"
  '';
  doInstallCheck = true;
  installCheckPhase = ''"$out/bin/neofetch" --config none --stdout'';

  meta = {
    description = "Customizable system information display";
    homepage = "https://github.com/dylanaraps/neofetch";
    license = lib.licenses.mit;
    mainProgram = "neofetch";
    platforms = lib.platforms.linux;
  };
}
