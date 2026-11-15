{ lib, pkgs, fixture }:
let
  workstation = (fixture {
    profile = ../profiles/laptop.nix;
    system = pkgs.stdenv.hostPlatform.system;
  }).config;
  phone = (fixture {
    profile = ../profiles/phone.nix;
    system = "aarch64-linux";
  }).config;
  home = workstation.home-manager.users.przvl;
  config = home.xdg.configFile."hypr/hyprland.lua".text;
in
assert workstation.programs.hyprland.enable;
assert !phone.programs.hyprland.enable;
assert lib.any (package: lib.getName package == "start-blix-hyprland") home.home.packages;
assert !(phone.home-manager.users.przvl.xdg.configFile ? "hypr/hyprland.lua");
assert lib.hasInfix ''general = { layout = "dwindle", gaps_out = 10 }'' config;
assert lib.hasInfix ''dwindle = { force_split = 2 }'' config;
assert lib.hasInfix ''natural_scroll = true,'' config;
assert lib.hasInfix ''touchpad = { natural_scroll = true }'' config;
assert lib.hasInfix ''hl.bind("SUPER + Return", exec('' config;
assert lib.hasInfix ''hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())'' config;
assert lib.hasInfix "for i = 1, 9 do" config;
pkgs.runCommand "hyprland-profile-checks" {} ''
  export FONTCONFIG_FILE=${home.xdg.configFile."hypr/fontconfig.conf".source}
  match=$(${pkgs.fontconfig}/bin/fc-match -f '%{family}|%{style}\n' 'JetBrainsMono Nerd Font:size=10')
  test "$match" = 'Tamsyn|Bold'
  touch "$out"
''
