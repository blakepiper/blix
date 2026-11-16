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
  monitorPolicy = pkgs.writeText "hyprland-monitors.lua" (builtins.replaceStrings
    [ "@primary-output@" ] [ "eDP-1" ]
    (builtins.readFile ../home/przvl/config/hyprland-monitors.lua));
  fontConfig = home.xdg.configFile."hypr/fontconfig.conf".source;
in
assert workstation.programs.hyprland.enable;
assert !phone.programs.hyprland.enable;
assert lib.any (package: lib.getName package == "start-blix-hyprland") home.home.packages;
assert lib.any (package: lib.getName package == "blix-hyprland-session-start") home.home.packages;
assert !(phone.home-manager.users.przvl.xdg.configFile ? "hypr/hyprland.lua");
assert lib.hasInfix ''general = { layout = "dwindle", gaps_out = { top = 4, right = 10, bottom = 10, left = 10 } }'' config;
assert lib.hasInfix ''hl.plugin.load("'' config;
assert lib.hasInfix ''/lib/libhyprglass.so")'' config;
assert lib.hasInfix ''enabled = false,'' config;
assert lib.hasInfix ''default_preset = "blix-glass"'' config;
assert lib.hasInfix ''match = { class = "^com[.]blix[.]ghostty-glass$" }'' config;
assert lib.hasInfix ''tag = "+hyprglass_enabled"'' config;
assert lib.hasInfix ''layers = { enabled = true }'' config;
assert lib.hasInfix ''"blix-workspace-glass", "blix-clock-glass", "blix-controls-glass"'' config;
assert lib.hasInfix ''match = { class = "^[.]blix-settings-wrapped$", title = "^Blix Settings$" }'' config;
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
assert lib.hasInfix ''active: controlPopup.visible || calendarPopup.visible'' bar;
assert lib.hasInfix ''windows: [panel, workspaceGlass, clockGlass, controlsGlass]'' bar;
assert lib.hasInfix ''controlPopup.visible = false;'' bar;
assert lib.hasInfix ''calendarPopup.visible = false;'' bar;
assert lib.hasInfix ''onClicked: panel.toggleCalendar()'' bar;
assert lib.hasInfix ''Qt.formatDateTime(calendarPopup.displayedMonth, "MMMM yyyy")'' bar;
assert lib.hasInfix ''firstWeekday: displayedMonth.getDay()'' bar;
assert lib.hasInfix ''property real expansion: calendarPopup.visible ? 1 : 0'' bar;
assert lib.hasInfix ''property real expansion: controlPopup.visible ? 1 : 0'' bar;
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
  ${pkgs.lua}/bin/lua ${./hyprland-monitors.lua} ${monitorPolicy}
  export FONTCONFIG_FILE=${fontConfig}
  match=$(${pkgs.fontconfig}/bin/fc-match -f '%{family}|%{style}|%{pixelsize}|%{antialias}|%{hintstyle}\n' 'JetBrainsMono Nerd Font:size=10')
  test "$match" = 'Tamsyn|Bold|16|False|3'
  touch "$out"
''
