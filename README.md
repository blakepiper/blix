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
└── common.nix                    Shared system configuration for every host

hosts/t490/
├── default.nix                   Hostname, laptop power, lid, state version
├── home.nix                      Monitor layout for this machine
└── hardware-configuration.nix    Generated hardware facts; edit rarely

home/przvl/
├── default.nix                   Home composition root and identity
├── packages.nix                  User packages
├── theme.nix                     Shared colors, font, and cursor values
├── resources.nix                 Pinned downloaded resources
├── programs/                     User applications
├── desktop/                      Hyprland session and appearance
│   └── monitors.nix              Declares the per-host blix.monitors option
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
  which is merged into the shared `home/przvl` configuration. The monitor
  layout (`blix.monitors`) is the current example; add an option in
  `home/przvl/` and set it per host rather than branching on the hostname.
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
   `system.stateVersion`, adds `home-manager.users.przvl = import ./home.nix;`,
   and adds anything else specific to that machine.
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

## Validation

Evaluate the complete host configuration with:

```sh
nix eval .#nixosConfigurations.t490.config.system.build.toplevel.drvPath --raw
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
