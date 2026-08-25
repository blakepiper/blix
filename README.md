![NixOS logo](https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nixos.svg)

# blix

Declarative NixOS and Home Manager configuration for Blix machines and the
`przvl` user. The repository currently defines one host, `t490`.

A complete machine is composed from five parts:

```text
modules/common/                   shared Blix system configuration
modules/<machine-class>/          optional reusable machine-class behavior
hosts/<host>/default.nix          host-specific composition and settings
hosts/<host>/hardware-configuration.nix   generated hardware facts
home/przvl/                       shared przvl Home Manager configuration
```

Host-specific Home Manager facts, such as monitor layouts, live in
`hosts/<host>/home.nix` and are merged into the shared user configuration.

## Repository map

```text
flake.nix                         Inputs and the nixosConfigurations outputs

modules/
├── common/
│   ├── default.nix               Aggregates the standard Blix environment
│   ├── boot.nix                  Shared UEFI/systemd-boot policy
│   ├── locale.nix                Shared timezone and locale policy
│   ├── nix.nix                   Nix, flakes, GC, and store optimization
│   ├── desktop-session.nix       Hyprland and SDDM
│   ├── desktop-services.nix      Audio, polkit, disks, and power reporting
│   ├── form-factor.nix           Declares and mirrors blix.formFactor
│   ├── networking.nix            Shared NetworkManager configuration
│   ├── users.nix                 Shared system user definitions
│   ├── fonts.nix                 Shared fonts
│   ├── packages.nix              Shared system packages
│   └── home-manager.nix          Shared Home Manager composition
└── laptop/
    ├── default.nix               Aggregates reusable laptop behavior
    ├── input.nix                 Greeter touchpad behavior
    └── power.nix                 Generic power profiles and lid policy

hosts/t490/
├── default.nix                   Host composition, hostname, Wi-Fi quirk, state version
├── power.nix                     T490 AC-device-specific power-profile service
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
  the appropriate file under `modules/common/`.
- Behavior reusable across laptops belongs in `modules/laptop/`; desktop hosts
  simply do not import that module.
- Behavior that depends on one machine's hardware, hostname, device names, or
  quirks belongs in `hosts/<host>/`.
- Generated hardware settings stay in that host's `hardware-configuration.nix`;
  never move filesystem UUIDs, kernel modules, or CPU settings into shared
  configuration.
- User applications and desktop behavior belong in `home/przvl/`, which every
  host shares.
- User settings that depend on the machine belong in `hosts/<host>/home.nix`,
  which is merged into the shared `home/przvl` configuration. Declare the
  option in `home/przvl/host.nix` and set it per host rather than branching on
  the hostname.
- User behavior shared by a *class* of machine branches on
  `config.blix.formFactor` (as the desktop bars do for battery and brightness
  indicators). System behavior is selected by importing the corresponding
  machine-class module from the host.
- Do not copy shared configuration into a host. Compose the common and
  machine-class modules, then add only that host's facts and exceptions.
- `system.stateVersion` is per host. Never copy it to a new machine; set it to
  the release that machine was installed with.
- Shared theme values belong in `theme.nix`; downloaded inputs belong in
  `resources.nix`; custom scripts belong in `scripts/`.

## Adding a host

1. Create `hosts/<hostname>/`.
2. Generate that machine's hardware module:
   `nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix`.
3. Write a small `hosts/<hostname>/default.nix` that imports
   `../../modules/common`, `./hardware-configuration.nix`, and any appropriate
   machine-class module such as `../../modules/laptop`.
4. Write `hosts/<hostname>/home.nix` with that machine's `blix.monitors`
   layout, then set the hostname, form factor, state version, and only the
   system behavior specific to that machine in its `default.nix`.
5. Register it in `flake.nix`:

```nix
nixosConfigurations = {
  t490 = mkHost { modules = [ ./hosts/t490 ]; };
  newhost = mkHost { modules = [ ./hosts/newhost ]; };
};
```

`mkHost` accepts a `system` argument for hosts on another platform, for example
`mkHost { modules = [ ./hosts/pi ]; system = "aarch64-linux"; }`.

6. Rebuild or install it with `sudo nixos-rebuild switch --flake .#<hostname>`
   or the corresponding installation command.

Nothing from `hosts/t490/` needs to be copied.

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
| Firefox | desktop portal `color-scheme`; applies live |
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

Firefox follows the desktop portal's live `color-scheme` setting, which
Hyprland's portal supports directly.

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
