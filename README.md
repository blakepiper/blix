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
- `st`, `dmenu`, `picom`, `xsecurelock`, `xss-lock`, `clipmenu`, and Xfe provide
  the terminal, launcher, compositor, locking, clipboard, and file-manager
  pieces.
- Home Manager creates the user services and scripts for display hotplugging,
  locking, clipboard history, screenshots, brightness, status, and audio.
- Firefox is managed with the Blix privacy policies and force-installed uBlock
  Origin, Dark Reader, and Enhancer for YouTube extensions.

## Repository map

```text
flake.nix                         Inputs, OXWM/st overlays, and host outputs
flake.lock                        Pinned nixpkgs and Home Manager revisions

profiles/
├── laptop.nix                    Common environment with laptop defaults
└── desktop.nix                   Common environment with desktop defaults

modules/common/
├── default.nix                   Shared module composition
├── boot.nix                      Shared UEFI/systemd-boot policy
├── desktop-session.nix           X11, startx, OXWM, and input behavior
├── desktop-services.nix          Graphics, PipeWire, polkit, and rtkit
├── fonts.nix                     Shared fonts
├── home-manager.nix              Shared Home Manager integration
├── locale.nix                    Locale and timezone
├── machine.nix                   Typed capabilities, lid policy, and profile defaults
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
└── st/                           Blix st configuration and patch

tests/machine-profiles.nix        Profile defaults and overrides checked by the flake
```

## Machine profiles

Each host imports either `../../profiles/laptop.nix` or
`../../profiles/desktop.nix`, plus its generated hardware module. Both profiles
include `modules/common`; hosts do not need to import it separately. `zen` and
`t490` inherit the laptop profile.

| Default | Laptop | Desktop |
| --- | --- | --- |
| `blix.machine.type` | `"laptop"` | `"desktop"` |
| `hasBattery`, `hasBacklight`, `hasTouchpad` | `true` | `false` |
| Lid close, on battery or external power | Suspend | Ignore |
| Lid close while docked | Ignore | Ignore |
| `blix.display.layout` | `"mirror"` | `"extend"` |

Capabilities are typed NixOS options under `blix.machine` and can be overridden
in `hosts/<host>/default.nix`. For example, a laptop without a controllable
panel backlight can set `blix.machine.hasBacklight = false`. The system passes
battery and backlight capabilities to Home Manager automatically. Desktop
profiles omit battery widgets, Fastfetch battery reporting, and battery/brightness
helpers; brightness bindings are only registered when a backlight is enabled. Battery
reporting still checks for actual hardware at session startup.

Charge thresholds, Wi-Fi power quirks, and panel-driver workarounds remain
host-specific. The profiles share manual suspend, locking before suspend, and
no automatic idle locking. Hosts can override individual logind lid defaults
through `services.logind.settings.Login`.

Display facts live in `hosts/<host>/home.nix`. Every host supplies
`blix.display.primaryOutput`: an internal connector such as `eDP-1` on a
laptop, or a monitor connector such as `DP-1` on a desktop. Extended layouts
use preferred modes and place other connected monitors to the right of the
primary monitor. Mirrored layouts use `externalOutput` and
`additionalExternalOutputs`, with `mirrorMode`/`mirrorRate` defaulting to
`1920x1080` and 60 Hz. `primaryScaleFrom` optionally sets a logical resolution
for the primary display outside mirrored operation. Hosts can override the
inherited layout, so a laptop can use extended monitors too.

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
2. Import `../../profiles/laptop.nix` or `../../profiles/desktop.nix` and the
   generated hardware module from the host's `default.nix`.
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

The OXWM overlay pins upstream OXWM 0.13.0 and carries the two Blix patches;
the `st-blix` overlay applies the local `st` configuration and scrollback/
URL patch.

## Validation

`nix flake check` also evaluates laptop and desktop profile fixtures and checks
their capabilities, generated user configuration, and host override behavior.

Evaluate every host and run the full closure builds before activation:

```sh
nix flake check
nix eval .#nixosConfigurations.zen.config.system.build.toplevel.drvPath --raw
nix eval .#nixosConfigurations.t490.config.system.build.toplevel.drvPath --raw
nix build .#nixosConfigurations.zen.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.t490.config.system.build.toplevel --no-link
```

Only after those checks succeed should a host be activated:

```sh
sudo nixos-rebuild switch --flake .#zen
```
