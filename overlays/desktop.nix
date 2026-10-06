final: prev:

{
  # Pin OXWM 0.13.0 with Blix's microphone key and mirrored-monitor fixes.
  oxwm = prev.oxwm.overrideAttrs (old: {
    version = "0.13.0";
    src = final.fetchFromGitHub {
      owner = "tonybanters";
      repo = "oxwm";
      rev = "fc4ada9ac4ee8e34ace203290a2b14d10e4671cc";
      hash = "sha256-PnEF4Qus7h0Wyr9U8mhQ83uWxfz6VUZ99I1YJgjUK6w=";
    };
    patches = (old.patches or [ ]) ++ [
      ../packaging/oxwm/0001-microphone-keysym.patch
      ../packaging/oxwm/0002-unique-mirrored-screens.patch
    ];
  });

  "st-blix" =
    let
      stWithConfig = prev.st.override {
        conf = builtins.readFile ../packaging/st/config.h;
        patches = [ ../packaging/st/0001-scrollback-and-urls.patch ];
      };
    in
    stWithConfig.overrideAttrs (old: {
      # Separate the upstream postPatch snippets when using a custom config.
      postPatch = final.lib.replaceStrings
        [ "config.def.hsubstituteInPlace" ]
        [ "config.def.h\nsubstituteInPlace" ]
        old.postPatch;
    });
}
