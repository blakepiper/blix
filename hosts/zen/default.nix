# ASUS Zenbook — host-specific configuration.
#
# Shared and laptop-class configuration is composed here with the generated
# hardware module and the few settings that genuinely depend on this machine.
{ ... }:

{
  imports = [
    ../../modules/common
    ../../modules/laptop
    ./hardware-configuration.nix
  ];

  # Home Manager settings that depend on this machine, merged with the
  # shared home/przvl configuration applied in modules/common/.
  home-manager.users.przvl = import ./home.nix;

  blix.formFactor = "laptop";

  networking.hostName = "zen";

  # This Lunar Lake panel trips a panel self-refresh bug in the xe driver: the
  # kernel logs "Selective fetch area calculation failed in pipe A" on every
  # boot, and a later modeset — locking the screen or handing the display to
  # the greeter — can then deadlock the display state buffer. The internal
  # panel freezes on its last frame and nothing in userspace can recover it,
  # which reads as the whole machine hanging. Turning off self-refresh keeps
  # the panel out of that path, at the cost of a little idle power.
  boot.kernelParams = [
    "xe.enable_psr=0"
    "xe.enable_psr2_sel_fetch=0"
    "xe.enable_panel_replay=0"
  ];

  # The NixOS release this machine was installed with. Per host; never copied
  # to a new machine.
  system.stateVersion = "26.05";
}
