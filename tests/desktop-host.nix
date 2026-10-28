# Evaluate the actual installation host, including its placeholder storage.
{ lib, pkgs, mkHost }:
let
  c = (mkHost { modules = [ ../hosts/desktop ]; }).config;
  h = c.home-manager.users.przvl;
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
assert c.boot.loader.systemd-boot.enable;
assert h.blix.display.primaryOutput == null;
assert h.home.file ? ".xinitrc";
assert h.home.file ? ".config/picom/picom.conf";
pkgs.runCommand "desktop-host-checks" { } ''touch "$out"''
