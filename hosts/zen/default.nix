# ASUS Zenbook — host-specific configuration.
#
# Shared configuration is composed here with the generated hardware module and
# the few settings that genuinely depend on this machine.
{ ... }:

{
  imports = [
    ../../profiles/laptop.nix
    ./hardware-configuration.nix
    ../../modules/hardware/graphics/intel.nix
  ];

  # Home Manager settings that depend on this machine, merged with the
  # workstation user configuration selected by the laptop profile.
  home-manager.users.przvl = import ./home.nix;

  networking.hostName = "zen";

  # Ignore the built-in ELAN touchscreen in libinput sessions.
  services.udev.extraRules = ''
    ACTION!="remove", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="ELAN9008:00 04F3:436C", ENV{ID_INPUT_TOUCHSCREEN}=="1", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  # The ASUS WMI battery driver exposes BAT0's native charge threshold;
  # TLP reapplies it after boot, resume, and AC/battery transitions.
  services.tlp = {
    enable = true;
    settings.STOP_CHARGE_THRESH_BAT0 = 79;
  };

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
