# Synthetic hardware for evaluation/build checks. Never activate or flash this
# fixture: it describes no real machine and guesses no OnePlus hardware facts.
{ mkHost }:

{ profile, system ? "x86_64-linux", bootloader ? true, display ? true, modules ? [ ] }:
mkHost {
  inherit system;
  modules = [
    profile
    ({ lib, ... }: {
      networking.hostName = "profile-check";
      system.stateVersion = "26.05";
      fileSystems = {
        "/" = { device = "none"; fsType = "tmpfs"; };
        "/boot" = { device = "/dev/disk/by-label/blix-test-efi"; fsType = "vfat"; };
      };
      # Supply a standard boot provider only for complete-system fixtures.
      # The phone profile itself intentionally selects no bootloader.
      boot.loader.systemd-boot.enable = lib.mkIf bootloader (lib.mkDefault true);
      home-manager.users.przvl = lib.optionalAttrs display {
        blix.display.primaryOutput = "DP-1";
      };
    })
  ] ++ modules;
}
