# Evaluate both profile classes even while all real hosts are laptops.
{ lib, pkgs, mkHost, stateVersion }:

let
  fixture = profile: extraModules: mkHost {
    modules = [
      profile
      # Reuse generated hardware only to make the test system evaluable; this
      # fixture is not a deployable host or a nixosConfigurations output.
      ../hosts/t490/hardware-configuration.nix
      {
        networking.hostName = "profile-check";
        system.stateVersion = stateVersion;
        home-manager.users.przvl.blix.display.primaryOutput = "DP-1";
      }
    ] ++ extraModules;
  };

  inspect = host:
    let
      cfg = host.config;
      home = cfg.home-manager.users.przvl;
      packages = map lib.getName home.home.packages;
      init = home.home.file.".xinitrc".text;
      fastfetch = home.programs.fastfetch.settings.modules;
    in
    builtins.seq cfg.system.build.toplevel.drvPath {
      inherit (cfg.blix.machine) type hasBattery hasBacklight hasTouchpad;
      inherit (home.blix.display) layout;
      touchpadScrolling = cfg.services.libinput.touchpad.naturalScrolling;
      lid = cfg.services.logind.settings.Login;
      batteryHelper = builtins.elem "oxwm-battery" packages;
      brightnessHelper = builtins.elem "blix-brightness" packages;
      batteryProbe = lib.hasInfix "for battery in" init;
      backlightBindings = lib.hasInfix "export BLIX_HAS_BACKLIGHT=1" init;
      batteryReporting = lib.any (module:
        builtins.isAttrs module && (module.type or "") == "battery"
      ) fastfetch;
      powerAdapterReporting = builtins.elem "poweradapter" fastfetch;
      hyprland = cfg.programs.hyprland.enable;
    };

  laptop = inspect (fixture ../profiles/laptop.nix [ ]);
  desktop = inspect (fixture ../profiles/desktop.nix [ ]);
  overrides = inspect (fixture ../profiles/desktop.nix [
    {
      blix.machine.hasBattery = true;
      blix.machine.hasBacklight = true;
      home-manager.users.przvl.blix.display.layout = "mirror";
      services.logind.settings.Login.HandleLidSwitch = "suspend";
    }
  ]);
  laptopOverrides = inspect (fixture ../profiles/laptop.nix [
    {
      blix.machine.hasBattery = false;
      blix.machine.hasBacklight = false;
      services.libinput.touchpad.naturalScrolling = false;
    }
  ]);
in
assert laptop.type == "laptop" && laptop.layout == "mirror";
assert laptop.hasBattery && laptop.hasBacklight && laptop.hasTouchpad;
assert laptop.batteryHelper && laptop.brightnessHelper && laptop.batteryProbe;
assert laptop.backlightBindings && laptop.batteryReporting && laptop.powerAdapterReporting;
assert laptop.lid.HandleLidSwitch == "suspend" && laptop.lid.HandleLidSwitchDocked == "ignore";
assert desktop.type == "desktop" && desktop.layout == "extend";
assert !desktop.hasBattery && !desktop.hasBacklight && !desktop.hasTouchpad;
assert !desktop.batteryHelper && !desktop.brightnessHelper && !desktop.batteryProbe;
assert !desktop.backlightBindings && !desktop.batteryReporting && !desktop.powerAdapterReporting;
assert desktop.lid.HandleLidSwitch == "ignore";
assert overrides.batteryHelper && overrides.brightnessHelper && overrides.batteryReporting;
assert overrides.layout == "mirror" && overrides.lid.HandleLidSwitch == "suspend";
assert !laptopOverrides.batteryHelper && !laptopOverrides.brightnessHelper;
assert !laptopOverrides.batteryReporting && !laptopOverrides.touchpadScrolling;
assert !laptop.hyprland && !desktop.hyprland;
pkgs.runCommand "machine-profile-checks" { } ''
  touch "$out"
''
