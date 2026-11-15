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
  bar = builtins.readFile ../home/przvl/config/quickshell/shell.qml;
  fontConfig = home.xdg.configFile."hypr/fontconfig.conf".source;
in
assert workstation.programs.hyprland.enable;
assert !phone.programs.hyprland.enable;
assert lib.any (package: lib.getName package == "start-blix-hyprland") home.home.packages;
assert lib.any (package: lib.getName package == "blix-hyprland-session-start") home.home.packages;
assert !(phone.home-manager.users.przvl.xdg.configFile ? "hypr/hyprland.lua");
assert lib.hasInfix ''general = { layout = "dwindle", gaps_out = 10 }'' config;
assert lib.hasInfix ''active_opacity = 0.85'' config;
assert lib.hasInfix ''inactive_opacity = 0.80'' config;
assert lib.hasInfix ''title = "^\\[blix-video\\] "'' config;
assert lib.hasInfix ''apply-transparency")'' config;
assert lib.hasInfix ''hyprsunset'' (lib.concatStringsSep " " home.systemd.user.services.blix-hyprsunset.Service.ExecStart);
assert lib.hasInfix ''apply-hyprland-nightlight'' home.systemd.user.services.blix-hyprsunset.Service.ExecStartPost;
assert !(home.systemd.user.targets ? "blix-hyprland-session");
assert lib.hasInfix ''text: currentTime'' bar;
assert lib.hasInfix ''Qt.formatDateTime(new Date(), "HH:mm")'' bar;
assert lib.hasInfix ''color: "#00000000"'' bar;
assert builtins.length (lib.strings.splitString "#00000000" bar) == 4;
assert lib.hasInfix ''windows: [panel, controlPopup]'' bar;
assert lib.hasInfix ''onCleared: controlPopup.visible = false'' bar;
assert lib.hasInfix ''PanelWindow {'' bar;
assert !(lib.hasInfix ''PopupWindow {'' bar);
assert lib.hasInfix ''exclusionMode: ExclusionMode.Ignore'' bar;
assert lib.hasInfix ''dwindle = { force_split = 2 }'' config;
assert lib.hasInfix ''natural_scroll = true,'' config;
assert lib.hasInfix ''touchpad = { natural_scroll = true }'' config;
assert lib.hasInfix ''hl.bind("SUPER + Return", exec('' config;
assert lib.hasInfix ''hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())'' config;
assert lib.hasInfix "for i = 1, 9 do" config;
pkgs.runCommand "hyprland-profile-checks" {} ''
  export FONTCONFIG_FILE=${fontConfig}
  match=$(${pkgs.fontconfig}/bin/fc-match -f '%{family}|%{style}|%{pixelsize}|%{antialias}|%{hintstyle}\n' 'JetBrainsMono Nerd Font:size=10')
  test "$match" = 'Tamsyn|Bold|16|False|3'
  touch "$out"
''
