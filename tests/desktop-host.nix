# Evaluate the installed Desktop host, including its detected storage.
{ lib, pkgs, mkHost }:
let
  c = (mkHost { modules = [ ../hosts/desktop ]; }).config;
  h = c.home-manager.users.przvl;
  panel = builtins.fromJSON (builtins.unsafeDiscardStringContext h.xdg.configFile."waybar/config".text);
  gpu = panel."custom/gpu";
in
assert c.networking.hostName == "desktop";
assert c.blix.machine.type == "desktop";
assert c.programs.steam.enable;
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
assert h.systemd.user.services.blix-monitor-brightness.Install.WantedBy == [ "blix-session.target" "blix-wayland-session.target" ];
assert h.systemd.user.services.blix-monitor-brightness.Unit.PartOf == [ "blix-session.target" "blix-wayland-session.target" ];
assert builtins.elem "blix-monitor-brightness.service" h.systemd.user.targets.blix-wayland-session.Unit.Wants;
assert lib.take 3 panel.modules-right == [ "pulseaudio" "custom/brightness" "memory" ];
assert !(builtins.elem "backlight" panel.modules-right);
assert panel."custom/brightness".exec == h.blix.wayland.brightnessCommand;
assert panel."custom/brightness".blix-popup-anchor;
assert lib.hasSuffix " monitor-brightness" panel."custom/brightness".on-click;
assert builtins.elem "custom/gpu" panel.modules-right;
assert gpu.interval == 5 && gpu.format == "GPU: {}" && !gpu.tooltip;
assert lib.hasInfix gpu.exec h.home.file.".config/oxwm/config.lua".text;
pkgs.runCommand "desktop-host-checks" {
  nativeBuildInputs = [ pkgs.python3 ];
  PANEL_CONFIG = h.xdg.configFile."waybar/config".source;
} ''
  python3 ${./monitor-brightness.py} ${../hosts/desktop/monitor-brightness.py} \
    ${h.home.file.".config/oxwm/config.lua".source}
  # No NVIDIA device in the sandbox: the shared command must degrade cleanly.
  python3 - <<'PYTEST'
  import json, os, subprocess
  with open(os.environ['PANEL_CONFIG']) as file:
      command = json.load(file)['custom/gpu']['exec']
  assert subprocess.check_output([command], text=True).strip() == 'N/A'
  PYTEST
  touch "$out"
''
