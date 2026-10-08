# Evaluate the shared foundation and a phone that replaces the desktop and
# user composition. These synthetic fixtures are never activated or flashed.
{ lib, pkgs, fixture }:

let
  foundation = fixture {
    profile = ../modules/common;
    system = pkgs.stdenv.hostPlatform.system;
    display = false;
    modules = [ { blix.machine.type = "desktop"; } ];
  };
  phone = fixture {
    profile = ../profiles/phone.nix;
    system = "aarch64-linux";
    display = false;
    modules = [ {
      # Replacing the selections keeps the phone's system policy and the
      # shared user identity/capabilities, without forcing inherited options.
      disabledModules = [ ../modules/desktop ];
      home-manager.users.przvl = { pkgs, ... }: {
        disabledModules = [ ../home/przvl/phone.nix ];
        programs.bash.enable = true;
        home.packages = with pkgs; [ hello ];
        home.file."phone-environment-check".text = "phone-only configuration";
      };
    } ];
  };
  laptop = fixture {
    profile = ../profiles/laptop.nix;
    system = pkgs.stdenv.hostPlatform.system;
  };
  withoutDesktop = host:
    let
      cfg = host.config;
      home = cfg.home-manager.users.przvl;
      packages = map lib.getName home.home.packages;
    in
    builtins.seq cfg.system.build.toplevel.drvPath (
      !cfg.services.xserver.enable
      && !cfg.services.xserver.windowManager.oxwm.enable
      && !cfg.services.blueman.enable
      && !home.services.blueman-applet.enable
      && !home.programs.firefox.enable
      && !home.programs.ghostty.enable
      && !(home.blix ? display)
      && !(home.home.file ? ".xinitrc")
      && !(home.systemd.user.targets ? blix-session)
      && !(home.systemd.user.services ? blix-display-hotplug)
      && !(home.systemd.user.services ? blix-picom)
      && !lib.any (name: builtins.elem name packages)
        [ "blix-settings" "xfe" "picom" "xsecurelock" "dmenu" ]
    );
  phoneHome = phone.config.home-manager.users.przvl;
  laptopHome = laptop.config.home-manager.users.przvl;
in
assert withoutDesktop foundation && withoutDesktop phone;
assert phone.config.blix.machine.type == "phone";
assert phone.config.nixpkgs.hostPlatform.system == "aarch64-linux";
assert phone.config.hardware.bluetooth.enable;
assert phoneHome.blix.hardware.hasBattery && phoneHome.blix.hardware.hasBacklight;
assert phoneHome.blix.hardware.hasBluetooth;
assert phone.config.services.upower.enable && phone.config.zramSwap.enable;
assert phone.config.services.logind.settings.Login.HandlePowerKey == "lock";
assert phoneHome.home.username == laptopHome.home.username;
assert phoneHome.home.stateVersion == laptopHome.home.stateVersion;
assert builtins.elem "hello" (map lib.getName phoneHome.home.packages);
assert !builtins.elem "hello" (map lib.getName laptopHome.home.packages);
assert !(laptopHome.home.file ? "phone-environment-check");
pkgs.runCommand "environment-composition-checks" { } ''
  touch "$out"
''
