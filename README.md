![NixOS logo](https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nixos.svg)

# blix

Declarative NixOS and Home Manager configuration for the `t490` host and
`przvl` user.

## Repository map

```text
hosts/t490/
├── default.nix                    Host composition root and state version
├── hardware-configuration.nix    Generated hardware facts; edit rarely
└── modules/
    ├── boot.nix                   Bootloader settings
    ├── networking.nix             Hostname and NetworkManager
    ├── locale.nix                 Time zone
    ├── nix.nix                    Nix features, garbage collection, policy
    ├── desktop-session.nix        Hyprland and greetd
    ├── desktop-services.nix       Audio and desktop support services
    ├── power.nix                  Laptop power and lid behavior
    ├── users.nix                  System user and groups
    ├── fonts.nix                  System fonts
    ├── packages.nix               System packages
    └── home-manager.nix           Home Manager integration

home/przvl/
├── default.nix                    Home composition root and identity
├── packages.nix                   User packages
├── theme.nix                      Shared colors, font, and cursor values
├── resources.nix                  Pinned downloaded resources
├── programs/                      User applications
├── desktop/                       Hyprland session and appearance
├── services/                      User services
└── scripts/                       Custom executable derivations
```

## Navigation rules

- System-wide behavior belongs in `hosts/t490/modules/`.
- User applications and desktop behavior belong in `home/przvl/`.
- Generated hardware settings stay in `hardware-configuration.nix`.
- `default.nix` files are composition points: they primarily import focused
  modules and establish the scope’s identity.
- Shared theme values belong in `theme.nix`; downloaded inputs belong in
  `resources.nix`; custom scripts belong in `scripts/`.

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
