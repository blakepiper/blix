<p align="center">
  <img src="assets/blix-logo.png" alt="Blix logo" width="314">
</p>

# blix

Declarative NixOS and Home Manager configuration for the `przvl` user. The
flake currently defines two hosts, `zen` and `t490`, with the same Blix-style
OXWM desktop session.

The desktop uses:

- Xorg is started manually with `startx`; there is no display manager.
- OXWM is the window manager, with the Blix configuration and local patches.
- Ghostty, `dmenu`, `picom`, `xsecurelock`, `xss-lock`, `clipmenu`, and Xfe provide
  the terminal, launcher, compositor, locking, clipboard, and file-manager
  pieces.
- Ghostty runs Bash with ble.sh for interactive editing, highlighting and
  completion. Home Manager manages its settings and Bash integration; OXWM's
  terminal binding uses the same executable as `$TERMINAL`.
  Clicking within the current shell command moves the editing cursor there.
- Home Manager creates the user services and scripts for display hotplugging,
  locking, clipboard history, screenshots, brightness, status, and audio.
- Firefox is managed with the Blix privacy policies and force-installed uBlock
  Origin, Dark Reader, and Enhancer for YouTube extensions. Its default profile
  includes the captured privacy preferences, vertical tabs, square corners,
  JetBrains Mono fonts, and dark PDF pages.
- Neovim uses LazyVim with the minimal theme. `nvimide [project-directory]`
  adds a left explorer and two stacked terminals on the right, with Neofetch
  in the second terminal. Plain `nvim` keeps the normal editor layout.

Firefox and Neovim configuration lives in `home/przvl/config/`; the application
modules own the Home Manager integration for these local files.
The Neovim adapter uses Nix-packaged Lua language server, StyLua and shfmt in
place of Mason downloads, and preserves the writable lazy.nvim lockfile.

## Repository map

```text
flake.nix                         Inputs, host composition, and checks
flake.lock                        Pinned nixpkgs and Home Manager revisions
lib/mk-host.nix                   Platform, overlays, and Home Manager wiring
overlays/desktop.nix              OXWM patches and the Neofetch package
overlays/codex.nix                Complete Codex runtime packaging

profiles/
├── laptop.nix                    Common environment with laptop defaults
├── desktop.nix                   Common environment with desktop defaults
└── phone.nix                     Ordinary Blix desktop with phone capabilities

modules/boot/uefi.nix             Optional UEFI/systemd-boot defaults

modules/common/
├── default.nix                   Shared module composition
├── boot.nix                      Bootloader-independent kernel policy
├── desktop-session.nix           X11, startx, OXWM, and input behavior
├── desktop-services.nix          Graphics, PipeWire, polkit, and rtkit
├── fonts.nix                     Shared fonts
├── home-manager.nix              Shared Home Manager integration
├── locale.nix                    Locale and timezone
├── machine.nix                   Typed capabilities and their shared behavior
├── networking.nix                NetworkManager
├── nix.nix                       Nix version, flakes, GC, and optimization
├── packages.nix                  Shared system utilities
└── users.nix                     Shared user definitions

hosts/<host>/
├── default.nix                   Profile inheritance and hardware quirks
├── hardware-configuration.nix    Generated hardware facts
└── home.nix                      Host-specific display connector settings

home/przvl/
├── default.nix                   Home Manager composition root
├── host.nix                      Typed user hardware/display options
├── packages.nix                  Blix user packages
├── programs/                     Bash, Firefox, Git, Neovim, tmux, and tools
├── services/blix.nix              Blix session target and user services
├── scripts/blix.nix               Wrapped Blix scripts
├── x11.nix                       Dotfiles and generated ~/.xinitrc
└── config/                       OXWM, Picom, Xfe, Neovim, and script assets

packaging/
├── oxwm/                         Patches applied to the pinned OXWM release
└── neofetch/                     Pinned Neofetch and NixOS compatibility fixes

tests/
├── default.nix                   Checks for x86_64-linux and aarch64-linux
├── profile-fixture.nix           Synthetic hardware for evaluation/build checks
├── machine-profiles.nix          Profile defaults and hardware overrides
├── display-hotplug.py            Monitor, rotation, scaling, and reconnect checks
└── session-settings.nix          Generated blanking and Xresources behavior
```

## Machine profiles

Each host imports a profile from `profiles/`, plus its hardware module. Every
profile includes `modules/common`; hosts do not need to import it separately.
`zen` and `t490` inherit the laptop profile. Profiles supply defaults, shared
modules implement capability-based behavior, and hosts supply facts and exceptions.

| Default | Laptop | Desktop | Phone |
| --- | --- | --- | --- |
| `blix.machine.type` | `"laptop"` | `"desktop"` | `"phone"` |
| `hasBattery`, `hasBacklight` | `true` | `false` | `true` |
| `hasTouchpad`, `hasLid` | `true` | `false` | `false` |
| `hasBluetooth` | `false` | `false` | `true` |
| Lid close, on battery or external power | Suspend | Ignore | Ignore |
| Lid close while docked | Ignore | Ignore | Ignore |
| `blix.display.layout` | `"mirror"` | `"extend"` | `"extend"` |
| `blix.display.blankAfterSeconds` | `0` | `0` | `300` |
| Boot provider | UEFI/systemd-boot | UEFI/systemd-boot | Supplied by hardware layer |

Capabilities are typed NixOS options under `blix.machine` and can be overridden
in `hosts/<host>/default.nix`. For example, a laptop without a controllable
panel backlight can set `blix.machine.hasBacklight = false`. The system passes
battery and backlight capabilities to Home Manager automatically. Desktop
profiles omit battery widgets, Neofetch battery reporting, and battery/brightness
helpers; brightness bindings are only registered when a backlight is enabled. Battery
reporting still checks for actual hardware at session startup. Lid behavior
uses `hasLid`, independently of the profile's name. Bluetooth support enables
BlueZ and its command-line tools; pairing and trust are established on the device.

Charge thresholds, Wi-Fi power quirks, and panel-driver workarounds remain
host-specific. The profiles share manual suspend and locking before suspend.
The phone profile also enables zram and UPower, requests orderly shutdown at 3%
battery, and makes a short power-button press lock the session. Automatic
suspend is left to verified host policy. Hosts can override individual logind
defaults through `services.logind.settings.Login`.

Display facts live in `hosts/<host>/home.nix`. Every host supplies
`blix.display.primaryOutput`: an internal connector such as `eDP-1` on a
laptop, or a monitor connector such as `DP-1` on a desktop. Extended layouts
use preferred modes and place other connected monitors to the right of the
primary monitor. Mirrored layouts use `externalOutput` and
`additionalExternalOutputs`, with `mirrorMode`/`mirrorRate` defaulting to
`1920x1080` and 60 Hz. `primaryScaleFrom` optionally sets a logical resolution
for the primary display outside mirrored operation. Hosts can override the
inherited layout, so a laptop can use extended monitors too.

`primaryRotation` accepts `"normal"`, `"left"`, `"right"`, or `"inverted"`.
Rotation is reapplied on startup and reconnect. `dpi` optionally sets X11,
Xft and GTK font/UI sizing; it defaults to `null` so existing hosts retain
their current sizing. Font changes may require restarting applications.
Rotation and DPI are host facts, rather than assumptions in the phone profile.
`blankAfterSeconds` controls idle DPMS display power-off; `0` disables it.

A desktop's `home.nix` can be as small as:

```nix
{ ... }:
{
  blix.display.primaryOutput = "DP-1";
}
```

## Starting the session

After logging into a TTY as `przvl`, run:

```sh
startx
```

The generated `~/.xinitrc` starts the user session target, initializes the
configured displays, starts Picom and the Blix helper services, and finally
executes OXWM. The display helper uses these environment variables, populated
from the host options:

```text
BLIX_DISPLAY_LAYOUT
BLIX_PRIMARY_OUTPUT
BLIX_PRIMARY_ROTATION
BLIX_DISPLAY_DPI
BLIX_EXTERNAL_OUTPUT
BLIX_ADDITIONAL_EXTERNAL_OUTPUTS
BLIX_MIRROR_MODE
BLIX_MIRROR_RATE
BLIX_PRIMARY_SCALE_FROM
BLIX_WALLPAPER
```

To leave the session, exit OXWM or use the configured lock/power controls and
return to the TTY.

## Adding a host

1. Create `hosts/<hostname>/` and generate its hardware module with
   `nixos-generate-config --show-hardware-config`.
2. Import the appropriate laptop, desktop, or phone profile and the hardware
   module from the host's `default.nix`. Supply any additional boot provider.
3. Set the hostname, the state version of that machine's installation, hardware
   quirks, capability overrides, and host-specific networking settings there.
   Connect its `home.nix` with `home-manager.users.przvl = import ./home.nix;`.
4. Set `blix.display.primaryOutput` and any other display values in `home.nix`.
5. Register the host in `flake.nix`:

```nix
nixosConfigurations = {
  zen = mkHost { modules = [ ./hosts/zen ]; };
  t490 = mkHost { modules = [ ./hosts/t490 ]; };
};
```

An ARM host uses `mkHost { system = "aarch64-linux"; modules = [ ./hosts/phone ]; }`.
Profiles choose capabilities; the host constructor chooses the package platform.

## Phone preparation

`profiles/phone.nix` prepares a regular native NixOS workstation using the same
OXWM, Xorg, Ghostty, dmenu, Firefox, Neovim and Home Manager configuration. It selects
no mobile shell, architecture, kernel, firmware, bootloader, partition layout,
display connector or rotation. Those decisions belong to the future host and
its hardware support modules.

The planned hardware is a OnePlus 6T (fajita) with a Bluetooth keyboard and
touchpad. Before registering `nixosConfigurations.phone`, verify a boot provider
that supports the intended standard NixOS boot and kernel-update workflow, add
the actual storage and firmware configuration, and inspect the display and
input devices. Set the observed connector and chosen landscape rotation in
`hosts/phone/home.nix`; tune DPI on the physical screen. Set `hasTouchpad = true`
if the Bluetooth device exposes a touchpad that should use the shared settings.

The flake currently keeps only `zen` and `t490` as deployable hosts. Its ARM
phone fixture evaluates the entire standard NixOS system and shared desktop
without borrowing x86 hardware facts. The fixture has synthetic storage and
UEFI settings solely for checking composition; it is not a 6T installation
image and must never be activated or flashed.

After delivery, validate Bluetooth reconnect, accelerated Xorg, landscape
display, brightness, charging, audio routing, locking, suspend/resume and
updates across reboots. Hardware dependencies remain pinned imports in the
finished host configuration.

## Updating inputs and Nix

The flake follows `nixpkgs/nixos-unstable` and Home Manager follows the locked
nixpkgs revision. The common Nix module selects `pkgs.nixVersions.latest`, so
the rebuilt system uses the newest Nix package supplied by the locked nixpkgs
revision. Refresh and review the lockfile with:

```sh
nix flake update
nix eval .#nixosConfigurations.zen.config.nix.package.version --raw
```

Codex comes from the [SecBear/codex-nix](https://github.com/SecBear/codex-nix)
overlay, which packages official upstream binaries and checks for stable
releases hourly. The same `nix flake update` refreshes this input; no manual
Codex version or hash edits are needed. Availability depends on the upstream
update workflow completing. The lockfile pins the resulting revision, and a
rebuild installs it. This adds a third-party packaging source, without adding
a binary cache or running a standalone installer.

`overlays/codex.nix` completes the binary package with the manifest, ripgrep,
and bubblewrap needed by Codex's background server. The helper binaries are
static and copied into the package because the daemon copies its installation
and rejects links outside the package. Codex still takes its version and
binary hashes from the locked `codex-nix` input. When checking an update, test
ordinary `codex` startup: `codex --version` and `codex --no-daemon` do not
exercise background-server installation.

Ghostty comes from nixpkgs; the current lock supplies 1.3.1, the
[latest stable release](https://ghostty.org/download) checked on 2026-10-06.
Updating nixpkgs refreshes Ghostty along with the other distribution packages.
The OXWM overlay pins upstream OXWM 0.13.0 and carries the two Blix patches.
`packaging/neofetch/` retains the original Neofetch package with its NixOS fixes.
Its settings and ASCII layout are local assets under `home/przvl/config/neofetch/`.

## Validation

`nix flake check` evaluates laptop, desktop and ARM phone profile fixtures,
checks generated user configuration and overrides, and runs display hotplug
regression checks. The ARM evaluation runs even on an x86 machine.

Evaluate every host and run the full closure builds before activation:

```sh
nix flake check
nix flake check --all-systems --no-build
nix eval .#nixosConfigurations.zen.config.system.build.toplevel.drvPath --raw
nix eval .#nixosConfigurations.t490.config.system.build.toplevel.drvPath --raw
nix build .#nixosConfigurations.zen.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.t490.config.system.build.toplevel --no-link
```

With an ARM machine or an aarch64 builder configured, realize the full synthetic
phone system to check the desktop and package closure:

```sh
nix build .#checks.aarch64-linux.phone-system --no-link
```

Evaluation does not require an ARM builder. Native ARM builds do; an x86
machine needs a remote ARM builder or configured emulation. Building this
fixture checks userspace composition and does not establish fajita boot support.

Only after those checks succeed should a host be activated:

```sh
sudo nixos-rebuild switch --flake .#zen
```
