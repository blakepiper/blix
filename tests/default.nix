{ lib, pkgs, mkHost, system }:

let
  fixture = import ./profile-fixture.nix { inherit mkHost; };
in
{
  machine-profiles = import ./machine-profiles.nix { inherit lib pkgs fixture; };
  session-settings = import ./session-settings.nix { inherit pkgs fixture; };
  keyboard-mapping = import ./keyboard-mapping.nix { inherit pkgs fixture; };
  bar-sliders = import ./bar-sliders.nix { inherit pkgs fixture; };
  bar-async = import ./bar-async.nix { inherit pkgs fixture; };
  display-hotplug = pkgs.runCommand "display-hotplug-checks" {
    nativeBuildInputs = [ pkgs.python3 pkgs.bash pkgs.coreutils pkgs.gawk ];
  } ''
    python3 ${./display-hotplug.py} ${../home/przvl/hardware/display-hotplug.sh}
    touch "$out"
  '';
} // lib.optionalAttrs (system == "aarch64-linux") {
  # A buildable ARM desktop/system check, not a deployable phone image.
  phone-system = (fixture {
    profile = ../profiles/phone.nix;
    inherit system;
  }).config.system.build.toplevel;
}
