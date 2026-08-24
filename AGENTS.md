# blix contributor guide

This repository is the declarative NixOS configuration for Blix machines and
the Home Manager configuration for the `przvl` user. It is structured for
multiple hosts; `t490` is currently the only one. Treat a successful Nix
evaluation as the minimum acceptance criterion for every configuration change.

## Repository map

- `flake.nix` declares the flake inputs and the `nixosConfigurations` outputs.
  Hosts are built through the `mkHost` helper, which always applies
  `modules/common.nix` and the Home Manager NixOS module.
- `flake.lock` pins all flake inputs.
- `modules/common.nix` owns shared system configuration that applies to every
  Blix machine.
- `modules/form-factor.nix` declares `blix.formFactor`, the `laptop`/`desktop`
  switch every host must set. It is mirrored into the przvl Home Manager
  configuration so user modules can branch on it.
- `modules/laptop.nix` owns configuration shared by every Blix laptop and is
  inert on desktops.
- `hosts/t490/default.nix` owns configuration specific to that machine and
  imports its generated hardware module.
- `hosts/t490/hardware-configuration.nix` contains detected hardware settings;
  change it only when the machine's hardware or generated configuration
  intentionally changes.
- `home/przvl/default.nix` owns the `przvl` user's packages, programs, services,
  and dotfile configuration, shared across hosts.
- `hosts/t490/home.nix` owns `przvl` Home Manager settings that depend on this
  machine, currently the `blix.monitors` layout declared in
  `home/przvl/desktop/monitors.nix`.

## Scope and ownership

- Put user applications and per-user desktop behavior in
  `home/przvl/default.nix`.
- Put system-wide services, packages, users, security, login, and desktop
  configuration that every Blix machine should have in `modules/common.nix`.
- Put only machine-dependent settings in `hosts/<hostname>/default.nix`:
  hostname, `system.stateVersion`, power and lid behavior, hardware quirks,
  and host-specific networking tweaks.
- Put machine-dependent user settings in `hosts/<hostname>/home.nix`. Declare a
  typed option in `home/przvl/host.nix` and set it per host; do not branch on
  the hostname inside shared user configuration.
- Put behavior common to a class of machine behind `blix.formFactor`:
  system-wide in `modules/laptop.nix`, user-level by testing
  `config.blix.formFactor`.
- Never move generated hardware facts out of a host's
  `hardware-configuration.nix`.
- Keep package names inside the existing `with pkgs;` package lists.
- Preserve `system.stateVersion` and `home.stateVersion`. Change either only as
  part of an explicit, researched state-version migration.
- Do not edit `flake.lock` unless the requested work includes changing or
  updating a flake input.
- Avoid broad formatting or structural rewrites when a focused edit is enough.
  Preserve unrelated user changes already present in the worktree.

## Working procedure

1. Inspect `git status` and the relevant configuration before editing.
2. For regressions, inspect recent commits and available system or user journal
   logs before selecting a fix. Prefer evidence from the running `t490` over
   assumptions about service behavior.
3. Make the smallest declarative change that addresses the request. Do not add
   imperative setup steps when a NixOS or Home Manager option exists.
4. Review the diff for accidental changes and run the required validation.
5. Activate only a configuration that has evaluated successfully.
6. Commit and push the scoped result as described below.

## Validation

Always check the patch and evaluate the complete host configuration:

```bash
git diff --check
nix eval .#nixosConfigurations.t490.config.system.build.toplevel.drvPath --raw
```

For changes that affect boot, login, the desktop session, systemd units,
packages, or generated files, also realize the full system closure:

```bash
nix build .#nixosConfigurations.t490.config.system.build.toplevel --no-link
```

Run narrower checks when they add confidence, such as inspecting an evaluated
option or using an application's configuration validator. Report any check that
could not be run and why; do not describe an unrun check as passing.

## Activation and recovery

Apply a verified configuration on `t490` with:

```bash
sudo nixos-rebuild switch --flake .#t490
```

- Do not attempt to bypass an interactive sudo prompt. If credentials are not
  available, leave the repository ready and provide the exact activation
  command.
- Do not reboot unless the user explicitly requests it or the requested change
  cannot take effect safely without one.
- Treat display-manager, compositor, PAM, bootloader, networking, and remote
  access changes as high-risk. Check the relevant journal after activation and
  preserve a usable TTY or previous boot generation for recovery.

Useful diagnostics for login and desktop-session failures include:

```bash
journalctl -b -u greetd --no-pager
journalctl --user -b --no-pager
loginctl list-sessions
```

## Git delivery

After completing and validating a request:

- Autonomously commit only the files changed for that request with a concise
  imperative commit message.
- Never include unrelated pre-existing worktree changes in the commit.
- Push the current branch to its configured upstream without force-pushing.
- Confirm the final branch status. If a safe scoped commit or push is not
  possible, stop and report the reason instead of disturbing other work.
