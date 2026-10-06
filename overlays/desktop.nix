final: prev:

{
  # Retain the original tool after its removal from nixpkgs.
  neofetch = final.callPackage ../packaging/neofetch { };

  # Pin OXWM 0.13.0 with Blix's keyboard, mirrored-monitor and bar-logo fixes.
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
      ../packaging/oxwm/0003-bar-logo.patch
    ];
    buildInputs = (old.buildInputs or [ ]) ++ [ final.libxpm ];
  });

}
