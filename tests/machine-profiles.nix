# Evaluate portable profiles, stationary profiles and hardware overrides.
{ lib, pkgs, fixture }:

let
  nativeFixture = profile: modules: fixture {
    inherit profile modules;
    system = pkgs.stdenv.hostPlatform.system;
  };

  inspect = host:
    let
      cfg = host.config;
      home = cfg.home-manager.users.przvl;
      packages = map lib.getName home.home.packages;
      init = home.home.file.".xinitrc".text;
      neofetch = home.xdg.configFile."neofetch/config.conf".text;
    in
    builtins.seq cfg.system.build.toplevel.drvPath {
      inherit (cfg.blix.machine) type hasBattery hasBacklight hasTouchpad hasLid hasBluetooth;
      inherit (home.blix.display) layout primaryRotation dpi blankAfterSeconds;
      architecture = cfg.nixpkgs.hostPlatform.system;
      touchpadScrolling = cfg.services.libinput.touchpad.naturalScrolling;
      lid = cfg.services.logind.settings.Login;
      bluetooth = cfg.hardware.bluetooth.enable && cfg.hardware.bluetooth.powerOnBoot;
      efiVariables = cfg.boot.loader.efi.canTouchEfiVariables;
      systemdBoot = cfg.boot.loader.systemd-boot.enable;
      oxwm = cfg.services.xserver.windowManager.oxwm.enable;
      batteryHelper = builtins.elem "oxwm-battery" packages;
      brightnessHelper = builtins.elem "blix-brightness" packages;
      batteryProbe = lib.hasInfix "for battery in" init;
      xinitShebang = lib.hasPrefix "#!/nix/store/" init;
      backlightBindings = lib.hasInfix "export BLIX_HAS_BACKLIGHT=1" init;
      batteryReporting = lib.hasInfix ''info "Battery" battery'' neofetch;
      hyprland = cfg.programs.hyprland.enable;
      xresources = home.xresources.properties;
      gtkDpi = home.gtk.gtk3.extraConfig.gtk-xft-dpi or null;
      consistentEnvironment = lib.all (name:
        builtins.elem "${name}=${home.home.sessionVariables.${name}}"
          home.systemd.user.services.blix-display-hotplug.Service.Environment
      ) (lib.filter (lib.hasPrefix "BLIX_") (builtins.attrNames home.home.sessionVariables));
    };

  laptop = inspect (nativeFixture ../profiles/laptop.nix [ ]);
  desktop = inspect (nativeFixture ../profiles/desktop.nix [ ]);
  overrides = inspect (nativeFixture ../profiles/desktop.nix [
    {
      blix.machine.hasBattery = true;
      blix.machine.hasBacklight = true;
      blix.machine.hasLid = true;
      blix.machine.hasBluetooth = true;
      home-manager.users.przvl.blix.display.layout = "mirror";
      boot.loader.efi.canTouchEfiVariables = false;
    }
  ]);
  laptopOverrides = inspect (nativeFixture ../profiles/laptop.nix [
    {
      blix.machine.hasBattery = false;
      blix.machine.hasBacklight = false;
      blix.machine.hasLid = false;
      services.libinput.touchpad.naturalScrolling = false;
    }
  ]);
  phoneHost = fixture {
    profile = ../profiles/phone.nix;
    system = "aarch64-linux";
  };
  phone = inspect phoneHost;
  phoneOverrides = inspect (fixture {
    profile = ../profiles/phone.nix;
    system = "aarch64-linux";
    modules = [ {
      blix.machine.hasBluetooth = false;
      blix.machine.hasTouchpad = true;
      home-manager.users.przvl.blix.display = {
        primaryRotation = "left";
        dpi = 192;
        blankAfterSeconds = 0;
      };
    } ];
  });
  phoneWithoutBoot = (fixture {
    profile = ../profiles/phone.nix;
    system = "aarch64-linux";
    bootloader = false;
  }).config;
in
assert laptop.type == "laptop" && laptop.layout == "mirror";
assert laptop.hasBattery && laptop.hasBacklight && laptop.hasTouchpad && laptop.hasLid;
assert laptop.batteryHelper && laptop.brightnessHelper && laptop.batteryProbe;
assert laptop.backlightBindings && laptop.batteryReporting;
assert laptop.lid.HandleLidSwitch == "suspend" && laptop.lid.HandleLidSwitchDocked == "ignore";
assert desktop.type == "desktop" && desktop.layout == "extend";
assert laptop.touchpadScrolling && desktop.touchpadScrolling && phone.touchpadScrolling;
assert !desktop.hasBattery && !desktop.hasBacklight && !desktop.hasTouchpad && !desktop.hasLid;
assert !desktop.batteryHelper && !desktop.brightnessHelper && !desktop.batteryProbe;
assert !desktop.backlightBindings && !desktop.batteryReporting;
assert desktop.lid.HandleLidSwitch == "ignore";
assert overrides.batteryHelper && overrides.brightnessHelper && overrides.batteryReporting;
assert overrides.layout == "mirror" && overrides.lid.HandleLidSwitch == "suspend";
assert overrides.bluetooth && !overrides.efiVariables;
assert !laptopOverrides.batteryHelper && !laptopOverrides.brightnessHelper;
assert !laptopOverrides.batteryReporting && !laptopOverrides.touchpadScrolling;
assert laptopOverrides.lid.HandleLidSwitch == "ignore";
assert laptop.systemdBoot && desktop.systemdBoot && laptop.efiVariables && desktop.efiVariables;
assert phone.type == "phone" && phone.architecture == "aarch64-linux";
assert phone.hasBattery && phone.hasBacklight && phone.hasBluetooth && phone.bluetooth;
assert !phone.hasLid && !phone.hasTouchpad && phone.lid.HandleLidSwitch == "ignore";
assert phone.lid.HandlePowerKey == "lock" && phone.layout == "extend";
assert phone.batteryHelper && phone.brightnessHelper && phone.batteryProbe && phone.batteryReporting;
assert phone.blankAfterSeconds == 300 && phone.primaryRotation == "normal" && phone.dpi == null;
assert phoneHost.config.services.upower.criticalPowerAction == "PowerOff";
assert phoneHost.config.zramSwap.enable && phoneHost.config.nix.settings.max-jobs == 1;
assert !phoneWithoutBoot.boot.loader.systemd-boot.enable;
assert !phoneWithoutBoot.boot.loader.efi.canTouchEfiVariables;
assert !phoneOverrides.bluetooth && phoneOverrides.touchpadScrolling;
assert phoneOverrides.primaryRotation == "left" && phoneOverrides.blankAfterSeconds == 0;
assert phoneOverrides.xresources."Xft.dpi" == 192 && phoneOverrides.gtkDpi == 192 * 1024;
assert lib.all (profile: profile.oxwm && !profile.hyprland && profile.consistentEnvironment && profile.xinitShebang)
  [ laptop desktop phone overrides laptopOverrides phoneOverrides ];
pkgs.runCommand "machine-profile-checks" { } ''
  touch "$out"
''
