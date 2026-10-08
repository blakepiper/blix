# Evaluate the real fajita host and its small bootstrap. These assertions cover
# integration boundaries; they cannot establish physical boot or driver support.
{ lib, pkgs, phone, phoneBootstrap }:

let
  cfg = phone.config;
  bootstrap = (phoneBootstrap pkgs.stdenv.hostPlatform.system).config;
  home = cfg.home-manager.users.przvl;
  inspectBoot = system:
    builtins.seq system.system.build.toplevel.drvPath (
      system.nixpkgs.hostPlatform.system == "aarch64-linux"
      && system.mobile.device.name == "oneplus-fajita"
      && system.mobile.system.type == "android"
      && system.mobile.system.android.ab_partitions
      && system.mobile.system.android.boot_as_recovery
      && system.mobile.system.android.system_partition_destination == "userdata"
      && !system.mobile.quirks.supportsStage-0
      && system.mobile.boot.stage-1.kernel.package.version == "6.4.0"
      && system.boot.loader.external.enable
      && !system.boot.loader.systemd-boot.enable
      && !system.boot.loader.grub.enable
      && !system.boot.loader.efi.canTouchEfiVariables
      && !system.boot.growPartition
      && system.fileSystems."/".device == "/dev/disk/by-label/NIXOS_SYSTEM"
      && system.fileSystems."/".fsType == "ext4"
      && system.fileSystems."/".autoResize
      && !(system.fileSystems ? "/boot")
    );
  inspectBootstrapAccess = system:
    let ssh = system.services.openssh; in
    system.networking.networkmanager.enable
    && system.mobile.boot.stage-1.networking.enable
    && !system.mobile.boot.stage-1.ssh.enable
    && ssh.enable && !ssh.openFirewall
    && ssh.settings.PermitRootLogin == "prohibit-password"
    && !ssh.settings.PasswordAuthentication
    && !ssh.settings.KbdInteractiveAuthentication
    && ssh.listenAddresses == [ { addr = "172.16.42.1"; port = 22; } ]
    && system.networking.firewall.interfaces.usb0.allowedTCPPorts == [ 22 ]
    && !(builtins.elem 22 system.networking.firewall.allowedTCPPorts)
    && system.users.users.root.password == null
    && system.users.users.przvl.password == null
    && system.users.users.root.openssh.authorizedKeys.keyFiles != [ ]
    && system.networking.networkmanager.ensureProfiles.profiles.blix-phone-usb-bootstrap.ipv4.address1
      == "172.16.42.1/24,172.16.42.2";
in
assert inspectBoot cfg && inspectBoot bootstrap;
assert inspectBootstrapAccess cfg && inspectBootstrapAccess bootstrap;
assert bootstrap.nixpkgs.buildPlatform.system == pkgs.stdenv.hostPlatform.system;
assert cfg.nixpkgs.buildPlatform.system == "aarch64-linux";
assert cfg.services.xserver.enable && cfg.services.xserver.windowManager.oxwm.enable;
assert cfg.services.xserver.displayManager.startx.enable;
assert !cfg.services.displayManager.gdm.enable && !cfg.services.desktopManager.gnome.enable;
assert cfg.services.pipewire.enable && cfg.services.pipewire.pulse.enable;
assert !cfg.services.pulseaudio.enable;
assert cfg.mobile.quirks.audio.alsa-ucm-meld;
assert cfg.environment.variables.ALSA_CONFIG_UCM2 == "/run/current-system/sw/share/alsa/ucm2";
assert cfg.hardware.graphics.enable && cfg.hardware.bluetooth.enable && cfg.services.blueman.enable;
assert cfg.blix.machine.hasTouchpad && !cfg.blix.machine.hasLid;
assert home.services.blueman-applet.enable;
assert home.blix.display.primaryOutput == null;
assert home.programs.firefox.enable && home.programs.ghostty.enable;
assert home.home.stateVersion == "26.05" && cfg.system.stateVersion == "26.11";
assert cfg.mobile.system.android.appendDTB == [ "dtbs/qcom/sdm845-oneplus-fajita.dtb" ];
assert !bootstrap.services.xserver.enable && !bootstrap.services.xserver.windowManager.oxwm.enable;
assert !bootstrap.home-manager.users.przvl.programs.firefox.enable;
assert !bootstrap.home-manager.users.przvl.programs.ghostty.enable;
assert !(bootstrap.home-manager.users.przvl.home.file ? ".xinitrc");
assert !lib.any (package: builtins.elem (lib.getName package) [ "codex" "xfe" "picom" ])
  bootstrap.home-manager.users.przvl.home.packages;
pkgs.runCommand "phone-hardware-checks" { } ''
  touch "$out"
''
