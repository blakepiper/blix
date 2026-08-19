# blix

This repository defines the NixOS configuration for the `t490` host and the
`przvl` Home Manager profile.

## Layout

- `flake.nix` and `flake.lock` define the Nix inputs and the `t490` output.
- `hosts/t490/default.nix` contains host- and system-level NixOS settings.
- `home/przvl/default.nix` contains user packages and Home Manager settings.

## Working conventions

- Make user-specific changes in `home/przvl/default.nix`; use the host module
  only for system-wide configuration.
- Keep package declarations in the existing `with pkgs;` lists.
- Preserve `system.stateVersion` and `home.stateVersion` unless performing an
  intentional migration.
- Do not modify `flake.lock` unless updating a flake input is part of the
  requested change.
- After completing and validating a requested change, autonomously commit the
  files changed for that request and push the current branch to its configured
  upstream. Do not include unrelated pre-existing worktree changes; if a safe,
  scoped commit or push is not possible, report why instead.

## Validation and activation

Evaluate the configuration before applying it:

```bash
nix eval .#nixosConfigurations.t490.config.system.build.toplevel.drvPath --raw
```

Apply a verified configuration on the `t490` machine:

```bash
sudo nixos-rebuild switch --flake .#t490
```
