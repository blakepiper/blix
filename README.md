![NixOS logo](https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nixos.svg)

# blix

Declarative NixOS and Home Manager configuration for Blix machines and the
`przvl` user. The repository currently defines one host, `t490`.

A complete machine is composed from four parts:

```text
modules/common.nix                shared Blix system configuration
home/przvl/                       shared przvl Home Manager configuration
hosts/<host>/default.nix          host-specific system configuration
hosts/<host>/home.nix             host-specific przvl Home Manager settings
hosts/<host>/hardware-configuration.nix   generated hardware facts
```

## Repository map

```text
flake.nix                         Inputs and the nixosConfigurations outputs

modules/
├── common.nix                    Shared system configuration for every host
├── form-factor.nix               Declares blix.formFactor ("laptop"/"desktop")
└── laptop.nix                    Applied to hosts whose form factor is laptop

hosts/t490/
├── default.nix                   Form factor, hostname, power quirks, state version
├── home.nix                      Monitor layout for this machine
└── hardware-configuration.nix    Generated hardware facts; edit rarely

home/przvl/
├── default.nix                   Home composition root and identity
├── host.nix                      Host facts: blix.formFactor and blix.monitors
├── packages.nix                  User packages
├── theme.nix                     Font and cursor shared by every theme
├── themes/                       The theme system; see "Themes" below
├── resources.nix                 Pinned downloaded resources
├── programs/                     User applications, including git and Neovim
├── desktop/                      Hyprland session and appearance
├── services/                     User services
└── scripts/                      Custom executable derivations
```

## Navigation rules

- Behavior that should apply to every Blix machine belongs in
  `modules/common.nix`.
- Behavior that depends on one machine's hardware, hostname, or form factor
  belongs in `hosts/<host>/default.nix`.
- Generated hardware settings stay in that host's `hardware-configuration.nix`;
  never move filesystem UUIDs, kernel modules, or CPU settings into shared
  configuration.
- User applications and desktop behavior belong in `home/przvl/`, which every
  host shares.
- User settings that depend on the machine belong in `hosts/<host>/home.nix`,
  which is merged into the shared `home/przvl` configuration. Declare the
  option in `home/przvl/host.nix` and set it per host rather than branching on
  the hostname.
- Behavior shared by a *class* of machine rather than by all of them belongs
  behind `blix.formFactor`: system-wide in `modules/laptop.nix`, user-level by
  testing `config.blix.formFactor` (as `desktop/bar.nix` does for the battery
  and brightness indicators).
- `system.stateVersion` is per host. Never copy it to a new machine; set it to
  the release that machine was installed with.
- Shared theme values belong in `theme.nix`; downloaded inputs belong in
  `resources.nix`; custom scripts belong in `scripts/`.

## Adding a host

1. Create `hosts/<hostname>/`.
2. Generate that machine's hardware module:
   `nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix`.
3. Write a small `hosts/<hostname>/default.nix` that imports
   `./hardware-configuration.nix`, sets `networking.hostName`, sets
   `system.stateVersion`, sets `blix.formFactor` to `"laptop"` or `"desktop"`,
   adds `home-manager.users.przvl = import ./home.nix;`, and adds anything else
   specific to that machine.
4. Write `hosts/<hostname>/home.nix` with that machine's `blix.monitors`
   layout, as reported by `hyprctl monitors`.
5. Register it in `flake.nix`:

```nix
nixosConfigurations = {
  t490 = mkHost { modules = [ ./hosts/t490 ]; };
  newhost = mkHost { modules = [ ./hosts/newhost ]; };
};
```

`mkHost` accepts a `system` argument for hosts on another platform, for example
`mkHost { modules = [ ./hosts/pi ]; system = "aarch64-linux"; }`.

Shared system and Home Manager configuration is applied automatically; nothing
from `hosts/t490/` needs to be copied.

## Themes

A theme is a palette in `home/przvl/themes/<name>.nix`. `themes/apps.nix` turns
one palette into a directory of per-application configuration files, and every
theme directory is installed to `~/.config/blix/themes`.

`~/.config/blix/current` is a symlink into one of those directories and is the
only mutable piece of the system. Switching themes re-points it and nudges the
running session, so no rebuild is needed:

```sh
blix-theme list       # every installed theme
blix-theme set NAME   # switch and apply
blix-theme menu       # pick from a list (what the bar widget runs)
```

The palette-picker widget sits at the left of the status bar's right group and
runs `blix-theme menu` on click.

Applications reach the active theme in one of two ways:

| Application | Mechanism |
|---|---|
| Alacritty | `general.import` of `current/alacritty.toml` |
| Fuzzel | `include` of `current/fuzzel.ini` |
| GTK 3 and 4 | `@import` of `current/gtk.css` |
| btop | `themes/blix.theme` symlinked into `current/`; select it once with `color_theme = "blix"` |
| Neovim | `mini.base16` built from `current/base16.lua` |
| Wayle | whole `config.toml` symlinked into `current/` |
| Hyprlock | whole `hyprlock.conf` symlinked into `current/` |
| hyprpaper | whole `hyprpaper.conf` symlinked into `current/`, plus an IPC push on switch |
| Hyprland | border colors set by `hyprctl` on switch and at session start |

### Adding a theme

Write `home/przvl/themes/<name>.nix` with a `label`, a `polarity` of `light` or
`dark`, a `wallpaper` path, and the `colors` set, then register it in the
`palettes` attribute of `themes/default.nix`. Wallpapers live in
`home/przvl/themes/wallpapers/` and are committed, so a new machine gets them
with the repository. Nothing else needs to change; every application file is
generated from the palette.

Colors belong only in a palette. An application module must never hardcode
one, or that application will stop following the active theme.

## Validation

Evaluate every host defined in the flake:

```sh
nix flake check
```

Build the complete system closure when changing desktop, services, packages,
or generated configuration:

```sh
nix build .#nixosConfigurations.t490.config.system.build.toplevel --no-link
```

## Updating packages

Packages in `home/przvl/packages.nix` are intentionally referenced by name,
without individual version pins. Their versions come from the locked
`nixpkgs` input. Refresh all flake inputs, then review and build the result:

```sh
nix flake update
nix eval .#nixosConfigurations.t490.pkgs.codex.version --raw
nix eval .#nixosConfigurations.t490.pkgs.claude-code.version --raw
nix build .#nixosConfigurations.t490.config.system.build.toplevel --no-link
sudo nixos-rebuild switch --flake .#t490
```

The lockfile remains committed so a rebuild is reproducible until the next
explicit update. Downloaded resources in `home/przvl/resources.nix` remain
content-addressed intentionally.
