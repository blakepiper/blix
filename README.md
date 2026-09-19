![NixOS logo](https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nixos.svg)

# blix

Declarative NixOS and Home Manager configuration for the `przvl` user. The
flake currently defines two hosts, `zen` and `t490`, with the same Blix-style
desktop session.

The active desktop is deliberately small and X11-based:

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

modules/common/
├── default.nix                   Shared module composition
├── boot.nix                      Shared UEFI/systemd-boot policy
├── desktop-session.nix           X11, startx, OXWM, and input behavior
├── desktop-services.nix          Graphics, PipeWire, polkit, and rtkit
├── fonts.nix                     Shared fonts
├── home-manager.nix              Shared Home Manager integration
├── locale.nix                    Locale and timezone
├── networking.nix                NetworkManager
├── nix.nix                       Nix version, flakes, GC, and optimization
├── packages.nix                  Shared system utilities
└── users.nix                     Shared user definitions

hosts/<host>/
├── default.nix                   Host composition and hardware quirks
├── hardware-configuration.nix    Generated hardware facts
└── home.nix                      Host-specific display connector settings

home/przvl/
├── default.nix                   Home Manager composition root
├── host.nix                      Typed host/display options
├── packages.nix                  Blix user packages
├── programs/                     Bash, Firefox, Git, Neovim, tmux, and tools
├── services/blix.nix              Blix session target and user services
├── scripts/blix.nix               Wrapped Blix scripts
├── x11.nix                       Dotfiles and generated ~/.xinitrc
└── config/                       OXWM, Picom, Xfe, Neovim, and script assets

packaging/
├── oxwm/                         Patches applied to the pinned OXWM release
└── st/                           Blix st configuration and patch
```

Host-specific display values live in `hosts/<host>/home.nix`. The defaults are
`eDP-1`, `HDMI-2`, `1920x1080`, and 60 Hz; change them there when a machine uses
different connector names or a different mirror mode.

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
BLIX_INTERNAL_OUTPUT
BLIX_EXTERNAL_OUTPUT
BLIX_MIRROR_MODE
BLIX_MIRROR_RATE
```

To leave the session, exit OXWM or use the configured lock/power controls and
return to the TTY.

## Adding a host

1. Create `hosts/<hostname>/` and generate its hardware module with
   `nixos-generate-config --show-hardware-config`.
2. Import `../../modules/common` and the generated hardware module from the
   host's `default.nix`.
3. Set the hostname, state version, hardware quirks, and any
   host-specific networking settings there.
4. Set the display connector and mirror values in `home.nix`.
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

The OXWM overlay pins upstream OXWM 0.13.0 and carries the two Blix patches;
the `st-blix` overlay applies the local `st` configuration and scrollback/
URL patch.

## Validation

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
