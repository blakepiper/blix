<p align="center">
  <img src="assets/blix-logo.png" alt="Blix logo" width="314">
</p>

# blix

Declarative NixOS and Home Manager configuration for the `przvl` user. The
flake currently defines two hosts, `zen` and `t490`, with the same Blix-style
OXWM desktop session. The phone profile has its own user composition so its
applications and environment can evolve independently.

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
  Ctrl-click opens links in Firefox; use Ctrl-Shift-click when a terminal
  application captures the mouse.
- Home Manager creates the user services and scripts for display hotplugging,
  locking, clipboard history, screenshots, brightness, status, and audio.
- Blix Settings is a native GTK app for display, audio, Bluetooth, networking,
  power and input controls. `Super+S` opens or focuses its window.
- Firefox is managed with the Blix privacy policies and force-installed uBlock
  Origin, Dark Reader, and Enhancer for YouTube extensions. Its default profile
  includes the captured privacy preferences, vertical tabs, square corners,
  JetBrains Mono fonts, and dark PDF pages.
- Neovim uses LazyVim with the minimal theme. `nvimide [project-directory]`
  adds a left explorer and two stacked terminals on the right, with Neofetch
  in the second terminal. Plain `nvim` keeps the normal editor layout.
- tmux is installed with its upstream defaults, without a Blix configuration
  or custom layout launcher.

Firefox and Neovim configuration lives in `home/przvl/config/`; the application
modules own the Home Manager integration for these local files.
The Neovim adapter uses Nix-packaged Lua language server, StyLua and shfmt in
place of Mason downloads, and preserves the writable lazy.nvim lockfile.

## Repository map

```text
flake.nix                         Inputs, host composition, and checks
flake.lock                        Pinned nixpkgs, Home Manager and Codex inputs
lib/mk-host.nix                   Platform, overlays, and Home Manager wiring
overlays/desktop.nix              OXWM patches and the Neofetch package
overlays/codex.nix                Complete Codex runtime packaging

profiles/
├── laptop.nix                    Shared workstation environment and laptop defaults
├── desktop.nix                   Shared workstation environment and desktop defaults
└── phone.nix                     Independent phone system and user composition

modules/boot/uefi.nix             Optional UEFI/systemd-boot defaults

modules/common/
├── default.nix                   Shared foundation without a desktop environment
├── boot.nix                      Bootloader-independent kernel policy
├── home-manager.nix              Home Manager wiring and shared user identity
├── locale.nix                    Locale and timezone
├── machine.nix                   Typed capabilities and Home Manager bridge
├── networking.nix                NetworkManager
├── nix.nix                       Nix version, flakes, GC, and optimization
├── packages.nix                  Shared system utilities
└── users.nix                     Shared user definitions

modules/desktop/
├── default.nix                   Optional desktop environment composition
├── session.nix                   X11, startx, and OXWM
├── services.nix                  Graphics, PipeWire, polkit, rtkit, and Blueman
├── fonts.nix                     Desktop fonts
└── packages.nix                  X11 utilities and graphics diagnostics

modules/hardware/
├── default.nix                   Session-independent Bluetooth and power policy
├── x11.nix                       Desktop input module composition
├── keyboard.nix                  Keyboard layout and repeat defaults
├── keyboards/mechanical.nix      Device-specific Cmd/Super mapping
├── mouse.nix                     Natural scrolling for ordinary mice
├── touchpad.nix                  Natural scrolling and click/tap defaults
├── power.nix                     Capability-based lid policy
└── bluetooth.nix                 Capability-based Bluetooth support

hosts/<host>/
├── default.nix                   Profile inheritance and hardware quirks
├── hardware-configuration.nix    Generated hardware facts
├── home.nix                      Machine-dependent Home Manager composition
└── display.nix                   Host display connectors and scaling

home/przvl/
├── base.nix                      Shared identity, state version and capabilities
├── default.nix                   Workstation user composition for zen and t490
├── phone.nix                     Independent phone application and session choices
├── environments/oxwm.nix         Reusable OXWM services, helpers and settings
├── hardware/
│   ├── default.nix               Typed user capabilities
│   ├── bluetooth.nix             Bluetooth manager and session pairing agent
│   ├── display.nix               Display options, helper package and service
│   └── display-hotplug.sh        Mirroring, extension and reconnect behavior
├── packages.nix                  Reusable command-line package selection
├── programs/                     Bash, Firefox, Git, Neovim, tmux, and tools
├── services/blix.nix              Blix session target and user services
├── scripts/blix.nix               Wrapped Blix scripts
├── x11.nix                       Dotfiles and generated ~/.xinitrc
└── config/                       OXWM, Picom, Xfe, Neovim, and script assets

packaging/
├── blix-settings/                Native settings app, backends and GTK styling
├── oxwm/                         Patches applied to the pinned OXWM release
└── neofetch/                     Pinned Neofetch and NixOS compatibility fixes

tests/
├── default.nix                   Checks for x86_64-linux and aarch64-linux
├── profile-fixture.nix           Synthetic hardware for evaluation/build checks
├── machine-profiles.nix          Profile defaults and hardware overrides
├── environment-composition.nix   Shared foundation and phone environment replacement
├── keyboard-mapping.nix          Compiled built-in and mechanical keymaps
├── keyboard-mapping.py           Win/Cmd modifier regression checks
├── display-hotplug.py            Monitor, rotation, scaling, and reconnect checks
├── blix-settings.nix             Settings backend and isolated GTK checks
└── session-settings.nix          Generated blanking and Xresources behavior
```

## Machine profiles

Each host imports a profile from `profiles/`, plus its hardware module. Every
profile includes `modules/common`; hosts do not need to import it separately.
The common foundation selects no desktop, GUI applications, display connector,
or user-session services. Profiles explicitly choose their system environment
and Home Manager composition.

`zen` and `t490` inherit the laptop profile and share `home/przvl/default.nix`.
The desktop profile uses that workstation composition too. The phone profile
selects `home/przvl/phone.nix`, which chooses reusable application modules
individually and does not import the workstation composition. All three profiles
currently opt into `modules/desktop` and `home/przvl/environments/oxwm.nix` to
preserve the existing environment. Profiles supply defaults, shared modules
implement capability-based behavior, and hosts supply facts and exceptions.

| Default | Laptop | Desktop | Phone |
| --- | --- | --- | --- |
| `blix.machine.type` | `"laptop"` | `"desktop"` | `"phone"` |
| `hasBattery`, `hasBacklight` | `true` | `false` | `true` |
| `hasTouchpad`, `hasLid` | `true` | `false` | `false` |
| `hasBluetooth` | `true` | `false` | `true` |
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
BlueZ and powers the controller on at boot. The selected desktop supplies Blueman
and the user session supplies its pairing agent.
The Blueman pairing agent starts with the Blix X11 session without requiring a
system tray. Launch `blueman-manager` from dmenu or a terminal to pair, trust and
connect devices. Pairing records stay on the machine; hosts can opt out with
`blix.machine.hasBluetooth = false`.

Charge thresholds, Wi-Fi power quirks, and panel-driver workarounds remain
host-specific. The profiles share manual suspend and locking before suspend.
The phone profile also enables zram and UPower, requests orderly shutdown at 3%
battery, and makes a short power-button press lock the session. Automatic
suspend is left to verified host policy. Hosts can override individual logind
defaults through `services.logind.settings.Login`.

Keyboard, mouse, touchpad, lid and Bluetooth policy live in separate files under
`modules/hardware/`. Natural scrolling applies to ordinary mice and all touchpads,
including external touchpads on desktop and phone hosts using the X11 environment.
The shared foundation includes only power and Bluetooth policy; the desktop
selects keyboard, mouse and touchpad policy through `modules/hardware/x11.nix`.
Pointing sticks and tablets retain their existing behavior. `hasTouchpad` enables
the additional tap and click defaults; scrolling can be overridden with
`services.libinput.touchpad.naturalScrolling`.

`keyboards/mechanical.nix` matches USB ID `1fc9:e8c7` and swaps Alt/Super for that
keyboard's Mac-mode Cmd key. Built-in laptop Win keys retain Super. Xorg applies
the rule when the device connects; no keyboard hotplug daemon or Xorg log parsing
is needed. New device-specific mappings belong alongside that module.

Display behavior and its dedicated hotplug service live in
`home/przvl/hardware/display.nix` and `display-hotplug.sh`. Display facts live in
`hosts/<host>/display.nix`, imported by the host's `home.nix`. Each host using the
X11 environment supplies `blix.display.primaryOutput`: an internal connector such
as `eDP-1` on a laptop, or a monitor connector such as `DP-1` on a desktop. Extended
layouts use preferred modes and place other connected monitors to the right of the
primary monitor. Mirrored layouts use `externalOutput` and
`additionalExternalOutputs`, with `mirrorMode` defaulting to `1920x1080`.
For each display, the helper selects the highest advertised refresh rate at the
chosen resolution: the preferred resolution for extended/undocked displays,
and `mirrorMode` for mirrored displays. Rates are selected independently, so a
slower monitor does not impose its rate on the others. `mirrorRate` defaults to
`null` for automatic selection; setting a value such as `"60"` explicitly pins
mirrored rates. If a driver rejects a selected rate, the helper retries the same
resolution with automatic refresh selection. It reapplies newly advertised
rates while ignoring duplicate events and changes to the active-mode marker.
`primaryScaleFrom` optionally sets a logical resolution
for the primary display outside mirrored operation. Hosts can override the
inherited layout, so a laptop can use extended monitors too.

`primaryRotation` accepts `"normal"`, `"left"`, `"right"`, or `"inverted"`.
Rotation is reapplied on startup and reconnect. `dpi` optionally sets X11,
Xft and GTK font/UI sizing; it defaults to `null` so existing hosts retain
their current sizing. Font changes may require restarting applications.
Rotation and DPI are host facts, rather than assumptions in the phone profile.
`blankAfterSeconds` controls idle DPMS display power-off; `0` disables it.

A desktop's `display.nix` can be as small as:

```nix
{ ... }:
{
  blix.display.primaryOutput = "DP-1";
}
```

## Blix Settings

Open `blix-settings` from a terminal or launcher, or press `Super+S`. The app
uses the existing NetworkManager, BlueZ, PipeWire/PulseAudio and X11 services;
it also includes a searchable shortcut reference and system information.

- Display controls cover mirror/extend layouts, monitor positions, resolutions,
  each output's advertised refresh rates, rotation, scaling and brightness.
  Applying a layout starts a 15-second confirmation window. A separate watchdog
  restores the previous layout if it is rejected, times out or the app closes.
- Audio controls select speakers and microphones, adjust volume and mute,
  play a test tone, and show an optional microphone level meter without recording.
- Bluetooth supports discovery, pairing confirmation, connection and forgetting
  devices. Networking supports Wi-Fi passwords, saved profiles and Ethernet
  status. Advanced Connections opens NetworkManager's editor for VPNs,
  enterprise authentication and detailed connection settings.
- Power shows battery and charge-limit information, configures display idle
  time, and offers locking and suspend. Input controls configure pointing-device
  speed, natural scrolling, touchpad tapping and keyboard repeat.

Nix supplies immutable, capability-based defaults in `~/.config/blix/defaults.json`.
User choices live separately in `~/.config/blix/settings.json`; Restore Defaults
removes the corresponding override. Display preferences are reapplied by the
existing hotplug helper, and saved input preferences return when matching
devices reconnect. NetworkManager owns Wi-Fi credentials and connection profiles;
BlueZ owns pairing records. Neither is copied into the settings file.

`blix-settings --demo` previews the interface with sample devices and in-memory
preferences. It does not change hardware or saved settings.

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

Firefox's local Blix Video Opacity extension marks a window's title with
`[blix-video]` while its active tab plays an HTML video, including embedded
videos and private windows. Picom makes only marked Firefox windows opaque;
pause, completion, navigation and tab switching restore ordinary transparency.
Tabs on x.com and its subdomains keep ordinary transparency, including when
they play videos in embedded frames. The detector also skips x.com documents.
The extension uses playback events and an idle-unloading background page, with
no polling or separate service. Shared Home Manager configuration loads its
immutable Nix package as a trusted built-in through Firefox AutoConfig; normal
addon signature checks and the web-content sandbox remain enabled. Its sources
live in `home/przvl/config/firefox/video-opacity/`; bump `manifest.json`'s version
when updating it. The isolated `firefox-video-opacity` check exercises playback,
window/tab/frame lifecycle, browser restarts and Picom's rendered opacity.

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
4. For the X11 environment, set `blix.display.primaryOutput` and any other display
   values in `display.nix`, and import that file from `home.nix`.
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

`profiles/phone.nix` owns phone system policy and chooses its system environment.
`home/przvl/phone.nix` independently selects phone applications, reusable program
configuration and user-session modules. The initial selection retains OXWM,
Xorg, Ghostty, dmenu, Firefox and Neovim. Workstation application additions in
`home/przvl/default.nix` or `home/przvl/programs/default.nix` do not automatically
reach the phone. Changes to an individual reusable program module still affect
every composition that imports it.

Put phone-specific applications and user behavior in `home/przvl/phone.nix` or
focused modules it imports. It can omit shared command-line packages or choose
different program modules without replacing the workstation's package list.
For a different session, replace the `modules/desktop` import in the phone system
profile and the `environments/oxwm.nix` import and desktop-specific application
and appearance modules in the phone user composition together. Replace X11-specific
display settings such as `blix.display.blankAfterSeconds` as part of that change.
The shared foundation remains usable without X11, a display connector or Blix
user services.

The phone profile selects no architecture, kernel, firmware, bootloader,
partition layout, display connector or rotation. Those decisions belong to the
future host and its hardware support modules.

The planned hardware is a OnePlus 6T (fajita) with a Bluetooth keyboard and
touchpad. Before registering `nixosConfigurations.phone`, verify a boot provider
that supports the intended standard NixOS boot and kernel-update workflow, add
the actual storage and firmware configuration, and inspect the display and
input devices. Set the observed connector and chosen landscape rotation in
`hosts/phone/display.nix`; tune DPI on the physical screen. Set `hasTouchpad = true`
if the Bluetooth touchpad should use the additional click/tap defaults. Natural
scrolling already applies regardless of that capability.

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
`packaging/ghostty/` backports the upstream Bash/ble.sh prompt fix to the
integration script while the terminal executable stays cached.
The wrapper preserves automatic shell integration and supplies `xdg-open` for
links; Firefox is also exported as the session's browser.
Neofetch uses its built-in NixOS logo.
The OXWM overlay pins upstream OXWM 0.13.0 and applies the Blix keyboard, monitor,
bar and tiling patches in `packaging/oxwm/`.
`packaging/neofetch/` retains the original Neofetch package with its NixOS fixes.
Its settings and ASCII layout are local assets under `home/przvl/config/neofetch/`.

## Validation

`nix flake check` evaluates laptop, desktop and ARM phone profile fixtures,
including a phone that replaces the default system and user environment while
retaining phone power policy and shared identity. It checks generated user
configuration and overrides, compiles keyboard mappings, and runs display
hotplug regression checks. The ARM evaluation runs even on an x86 machine.

When intentionally changing the phone environment, update its fixture settings
and expectations in `tests/`, including `machine-profiles.nix` and
`session-settings.nix`. Keep the shared-foundation and environment-replacement
checks in `environment-composition.nix`.

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
