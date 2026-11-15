# Evaluate the installed Desktop host, including its detected storage.
{ lib, pkgs, mkHost }:
let
  c = (mkHost { modules = [ ../hosts/desktop ]; }).config;
  h = c.home-manager.users.przvl;
  hyprlandConfig = h.xdg.configFile."hypr/hyprland.lua".text;
  hyprlandBar = lib.findFirst (package: lib.getName package == "blix-hyprland-bar")
    (throw "Desktop Hyprland bar is missing") h.home.packages;
in
assert c.networking.hostName == "desktop";
assert c.blix.machine.type == "desktop";
assert c.programs.steam.enable;
assert c.programs.hyprland.enable;
assert !c.blix.machine.hasBattery && !c.blix.machine.hasLid;
assert !c.blix.machine.hasBacklight && !c.blix.machine.hasTouchpad;
assert !h.blix.hardware.hasBattery && !h.blix.hardware.hasBacklight;
assert !h.blix.hardware.hasPowerProfiles && !c.services.tlp.enable;
assert c.services.logind.settings.Login.HandleLidSwitch == "ignore";
assert c.services.logind.settings.Login.HandleLidSwitchExternalPower == "ignore";
assert c.services.logind.settings.Login.HandleLidSwitchDocked == "ignore";
assert !(lib.hasInfix "touchpad =" hyprlandConfig);
assert !(lib.hasInfix "XF86MonBrightness" hyprlandConfig);
assert !(lib.hasInfix "mirror =" hyprlandConfig);
assert lib.hasInfix ''hl.bind("SUPER + G",'' hyprlandConfig;
assert h.systemd.user.services ? blix-hypridle;

assert c.hardware.graphics.enable && c.hardware.graphics.enable32Bit;
assert c.services.xserver.videoDrivers == [ "nvidia" ];
assert c.hardware.nvidia.open && c.hardware.nvidia.modesetting.enable;
assert c.hardware.nvidia.powerManagement.enable;
assert !c.hardware.nvidia.powerManagement.finegrained;
assert c.hardware.nvidia.moduleParams.nvidia.NVreg_PreserveVideoMemoryAllocations == 1;
assert c.hardware.nvidia.moduleParams.nvidia.NVreg_TemporaryFilePath == "/var/tmp";
assert c.hardware.nvidia.powerManagement.kernelSuspendNotifier
  || (lib.elem "systemd-suspend.service" c.systemd.services.nvidia-suspend.requiredBy
    && lib.elem "systemd-suspend.service" c.systemd.services.nvidia-resume.after);
assert c.zramSwap.enable && c.powerManagement.enable;
assert c.systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS == "false";
assert c.boot.loader.systemd-boot.enable;
assert h.blix.display.primaryOutput == null;
assert h.home.file ? ".xinitrc";
assert h.home.file ? ".config/picom/picom.conf";
assert h.systemd.user.services.blix-monitor-brightness.Install.WantedBy == [ "blix-session.target" ];
assert h.systemd.user.services.blix-monitor-brightness.Unit.PartOf == [ "blix-session.target" ];
assert lib.hasInfix "GPU: {}" h.home.file.".config/oxwm/config.lua".text;
pkgs.runCommand "desktop-host-checks" {
  nativeBuildInputs = [ pkgs.python3 ];
} ''
  python3 ${./monitor-brightness.py} ${../hosts/desktop/monitor-brightness.py} \
    ${h.home.file.".config/oxwm/config.lua".source}
  python3 - ${hyprlandBar}/bin/blix-hyprland-bar <<'PY'
  import pathlib, re, sys
  launcher = pathlib.Path(sys.argv[1]).read_text()
  qml_path = re.search(r"--path (/nix/store/[^\s]+)", launcher).group(1)
  qml = pathlib.Path(qml_path).read_text()
  assert 'visible: false && root.battery !== ""' in qml, "Desktop battery icon must be hidden"
  assert 'visible: false && root.brightness !== ""' in qml, "Desktop has no panel backlight"
  assert qml.count('running: false || false') == 2, "Desktop must not poll laptop sensors"
  assert 'running: false\n' in qml, "Desktop must not query laptop power profiles"
  PY
  touch "$out"
''
