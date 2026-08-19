# blix contributor guide

This repository is the declarative NixOS configuration for the `t490` host and
the Home Manager configuration for the `przvl` user. Treat a successful Nix
evaluation as the minimum acceptance criterion for every configuration change.

## Repository map

- `flake.nix` declares the flake inputs and the
  `nixosConfigurations.t490` output.
- `flake.lock` pins all flake inputs.
- `hosts/t490/default.nix` owns host-wide NixOS configuration and imports the
  generated hardware module.
- `hosts/t490/hardware-configuration.nix` contains detected hardware settings;
  change it only when the machine's hardware or generated configuration
  intentionally changes.
- `home/przvl/default.nix` owns the `przvl` user's packages, programs, services,
  and dotfile configuration.

## Scope and ownership

- Put user applications and per-user desktop behavior in
  `home/przvl/default.nix`.
- Put boot, hardware, networking, users, security, login, and other system-wide
  services in `hosts/t490/default.nix`.
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
