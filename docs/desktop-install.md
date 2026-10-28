# Desktop installation

Prepared host: Ryzen 5 5600X, RTX 3070, 32 GiB RAM, x86_64 UEFI.
This configuration has not been booted on the target. Motherboard, SSD device,
network controller, monitor connectors/DPI and firmware sleep support remain
unobserved. Replace the tracked hardware template during installation.
The initial system state version is 26.05; retain it on later upgrades.

The desktop profile supplies the existing X11/OXWM, picom and Home Manager
applications. Steam is the only host-specific application. NVIDIA uses the
pinned kernel's stable driver, open kernel modules (Ampere is supported), DRM
modesetting and both 64/32-bit graphics. NVIDIA userspace remains proprietary.
No PRIME offload or laptop runtime D3 policy is enabled for this single-GPU PC.

VRAM preservation uses `/var/tmp` on the ext4 root, rather than tmpfs; keep at
least 9 GiB free there for the 8 GiB GPU plus overhead. NixOS supplies the sleep
integration matching the driver: the pinned 595 driver uses kernel suspend
notifiers with open modules, so separate NVIDIA sleep services are unnecessary.
Older supported drivers use the module's systemd services instead. Firmware
and the kernel select the supported suspend state; no `mem_sleep_default` is
forced. zram uses 25% of RAM; this layout does not provide disk hibernation.

## Live USB and disk preparation

1. Boot an x86_64 NixOS live USB in UEFI mode. Disable Secure Boot unless you
   independently arrange signed boot and NVIDIA modules. Connect the monitor
   to the RTX 3070 (the 5600X has no integrated GPU). Establish networking.

   ```bash
   test -d /sys/firmware/efi
   lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN
   ls -l /dev/disk/by-id/
   ```

2. Identify the **entire target SSD** by model and serial. Back up its data.
   Replace the example below with its stable whole-disk path, without a `-part`
   suffix. The following partitioning and formatting commands **ERASE ALL DATA
   ON THAT SSD**. They are installation instructions only; none ran during
   repository preparation.

   ```bash
   DISK=/dev/disk/by-id/REPLACE_WITH_TARGET_SSD
   lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINTS "$DISK"
   # Stop here unless this is the intended disk and all its partitions are unmounted.
   sudo parted --script "$DISK" mklabel gpt
   sudo parted --script "$DISK" mkpart ESP fat32 1MiB 1025MiB
   sudo parted --script "$DISK" set 1 esp on
   sudo parted --script "$DISK" mkpart root ext4 1025MiB 100%
   sudo partprobe "$DISK"
   sudo udevadm settle
   sudo mkfs.fat -F 32 -n BLIX_EFI "${DISK}-part1"
   sudo mkfs.ext4 -L blix-root "${DISK}-part2"
   sudo mount "${DISK}-part2" /mnt
   sudo mkdir -p /mnt/boot
   sudo mount "${DISK}-part1" /mnt/boot
   findmnt /mnt
   findmnt /mnt/boot
   ```

   The ESP is exactly 1 GiB; ext4 takes the remaining usable space. No disk swap
   partition is needed for suspend-to-RAM.

3. Clone the repository into the target user's home. HTTPS avoids needing your
   private SSH key on the live USB. Run the following from the live environment:

   ```bash
   sudo mkdir -p /mnt/home/przvl
   sudo git clone https://github.com/blakepiper/blix.git /mnt/home/przvl/blix
   cd /mnt/home/przvl/blix
   sudo nixos-generate-config --root /mnt
   sudo cp /mnt/etc/nixos/hardware-configuration.nix hosts/desktop/hardware-configuration.nix
   cat hosts/desktop/hardware-configuration.nix
   ```

   Verify the generated root and `/boot` UUIDs match `lsblk -f`, architecture is
   x86_64, and detected storage/controller modules are present. Do not import
   `/mnt/etc/nixos/configuration.nix`: the flake supplies the system policy.
   Generation must run on the target, not an installation helper machine.

4. Evaluate the completed target and install:

   ```bash
   sudo nix --extra-experimental-features 'nix-command flakes' eval \
     .#nixosConfigurations.desktop.config.system.build.toplevel.drvPath --raw
   sudo nixos-install --flake .#desktop
   sudo nixos-enter --root /mnt -c 'passwd przvl'
   sudo nixos-enter --root /mnt -c 'chown -R przvl:users /home/przvl'
   ```

   `nixos-install` also prompts for a root password. Set the `przvl` password
   before rebooting; it has no preconfigured password. Retain and commit the
   generated hardware file after installation. Do not change the lock file.
   Finish with `sudo umount -R /mnt`, then reboot and remove the USB.

## First boot and physical checks

Log in as `przvl` on the console and run `startx`. The shared session starts
OXWM and picom; no display manager or automatic login is added.

```bash
hostname
nvidia-smi
lsmod | rg 'nvidia|nouveau'
cat /sys/module/nvidia_drm/parameters/modeset
cat /proc/driver/nvidia/params | rg 'PreserveVideoMemoryAllocations|TemporaryFilePath|UseKernelSuspendNotifiers'
xrandr --query
systemctl --user status blix-picom.service
nix shell --inputs-from . nixpkgs#mesa-demos nixpkgs#vulkan-tools --command bash -c 'glxinfo -B; vulkaninfo --summary'
```

Run the diagnostic shell from `~/blix`; `--inputs-from .` uses its pinned
Nixpkgs for the temporary tools. GLX/Vulkan should report
NVIDIA RTX 3070, with direct rendering rather than llvmpipe. Choose connector,
DPI and multi-monitor preferences from observed `xrandr` output and record fixed
hardware facts in `hosts/desktop/display.nix` if needed; runtime auto-selection
works without guessing DP/HDMI names.

Launch `steam` as `przvl`, sign in, enable Steam Play/Proton for the desired
Windows game, and test an installed title. Steam obtains its runtime and Proton
through the normal client. No unsolicited firewall ports are opened for Remote
Play or dedicated servers.

Save work, then test with an open terminal and later with Steam running:

```bash
cat /sys/power/state
cat /sys/power/mem_sleep
df -h /var/tmp
systemctl suspend
# Wake with the power button/keyboard, unlock, and verify the same session.
nvidia-smi
journalctl -b -u systemd-suspend.service --no-pager
journalctl -b -k --no-pager | rg -i 'nvidia|NVRM|Xid|PM:|suspend|resume'
```

The bracketed `mem_sleep` entry is selected by the kernel. Verify several cycles
and check for rendering corruption or Xid errors. Physical wake behavior and
GPU recovery cannot be established by flake evaluation or builds. Record any
investigation in `/home/przvl/systemdebugging.md`; desktop-only workarounds
belong in the desktop host or its explicitly imported hardware module, not Zen.
