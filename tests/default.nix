{ lib, pkgs, mkHost, system, phone, phoneBootstrap }:

let
  fixture = import ./profile-fixture.nix { inherit mkHost; };
in
{
  machine-profiles = import ./machine-profiles.nix { inherit lib pkgs fixture; };
  environment-composition = import ./environment-composition.nix { inherit lib pkgs fixture; };
  phone-hardware = import ./phone-hardware.nix { inherit lib pkgs phone phoneBootstrap; };
  session-settings = import ./session-settings.nix { inherit pkgs fixture; };
  keyboard-mapping = import ./keyboard-mapping.nix { inherit pkgs fixture; };
  bar-sliders = import ./bar-sliders.nix { inherit pkgs fixture; };
  bar-async = import ./bar-async.nix { inherit pkgs fixture; };
  firefox-video-opacity = import ./firefox-video-opacity.nix { inherit pkgs fixture; };
  blix-settings = import ./blix-settings.nix { inherit lib pkgs; };
  display-hotplug = pkgs.runCommand "display-hotplug-checks" {
    nativeBuildInputs = [ pkgs.python3 pkgs.bash pkgs.coreutils pkgs.gawk pkgs.util-linux ];
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
