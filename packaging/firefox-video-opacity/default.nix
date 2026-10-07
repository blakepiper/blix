{ runCommand, nodejs }:

let
  source = ../../home/przvl/config/firefox/video-opacity;
  manifest = builtins.fromJSON (builtins.readFile (source + /manifest.json));
in
runCommand "blix-firefox-video-opacity-${manifest.version}" {
  nativeBuildInputs = [ nodejs ];
} ''
  mkdir -p "$out/share/firefox-video-opacity"
  cp ${source}/{manifest.json,background.js,content.js} \
    "$out/share/firefox-video-opacity/"
  node --check "$out/share/firefox-video-opacity/background.js"
  node --check "$out/share/firefox-video-opacity/content.js"
''
