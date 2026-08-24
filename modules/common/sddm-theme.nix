{ pkgs }:

let
  revision = "292c87b770ff9eab1903dd2c6ddff466faf87fb0";
  source = pkgs.fetchFromGitHub {
    owner = "Keyitdev";
    repo = "sddm-astronaut-theme";
    rev = revision;
    hash = "sha256-O/EMJc1j2TRF3W+vuurzA9j5eG1OXSjGFrYxQbp99KU=";
  };
in
pkgs.runCommand "blix-sddm-theme" { } ''
  cp -r ${source} "$out"
  chmod -R u+w "$out"
  substituteInPlace "$out/metadata.desktop" \
    --replace-fail \
      "ConfigFile=Themes/astronaut.conf" \
      "ConfigFile=Themes/hyprland_kath.conf"

  # The theme selects its bundled pixelon face by family name, so also expose
  # its fonts through the normal fontconfig package layout.
  mkdir -p "$out/share/fonts/truetype"
  cp -r "$out"/Fonts/* "$out/share/fonts/truetype/"
''
