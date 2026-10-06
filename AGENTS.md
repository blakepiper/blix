# blix contributor guide

This repository is the declarative NixOS configuration for Blix machines and
the Home Manager configuration for the `przvl` user. It is structured for
multiple hosts; `zen` and `t490` are currently defined. Treat a successful Nix
evaluation as the minimum acceptance criterion for every configuration change.

## Global rules

- Whenever investigating or fixing any system issue on this machine, record the
  date, symptoms, relevant evidence, actions taken, and outcome in
  `/home/przvl/systemdebugging.md`.
- After each such investigation or fix, assess whether it should be captured
  declaratively in the next version of this machine's Nix flake. For this
  machine, that means considering the `#zen` configuration in this `blix`
  repository; record whether a flake change is needed and make the appropriate
  NixOS or Home Manager change when it is.

## Repository map

- `flake.nix` declares inputs, host outputs and per-platform checks.
  `lib/mk-host.nix` supplies the package platform, overlays and Home Manager
  NixOS module; each host explicitly imports its profile and hardware modules.
- `overlays/desktop.nix` owns OXWM and Neofetch packaging; `overlays/codex.nix` owns
  the Codex runtime packaging additions.
- `flake.lock` pins all flake inputs.
- `tests/` checks laptop, desktop and ARM phone defaults, overrides and display
  hotplug behavior. Its synthetic fixtures must never be activated or flashed.
- `profiles/laptop.nix`, `profiles/desktop.nix` and `profiles/phone.nix` compose
  the common environment and select inherited defaults. Every host imports one
  profile. Profiles describe capabilities independently of CPU architecture.
- `modules/boot/uefi.nix` supplies optional PC boot defaults. Shared common
  modules and the phone profile do not select a bootloader or device kernel.
- `modules/common/default.nix` aggregates shared system modules for the
  standard Blix environment. Its sibling files separate boot, locale, Nix,
  networking, users, fonts, packages, the X11/OXWM session and its services,
  Home Manager integration, and the shared user configuration.
- `modules/common/machine.nix` declares typed machine capabilities, supplies
  capability-based lid, touchpad and Bluetooth policy, and passes user
  capabilities to Home Manager. Behavior must not branch on the machine type.
- `hosts/<hostname>/default.nix` owns configuration specific to that machine
  and composes a machine profile, its generated hardware module, and genuinely
  device-specific settings.
- `hosts/<hostname>/hardware-configuration.nix` contains detected hardware;
  change it only when the machine's hardware or generated configuration
  intentionally changes.
- `home/przvl/default.nix` owns the `przvl` user's packages, programs, services,
  and dotfile configuration, shared across hosts.
- `home/przvl/config/` owns the Blix-derived OXWM, Picom, Xfe, Neovim, tmux,
  Neofetch, and helper-script configuration.
- `hosts/<hostname>/home.nix` owns `przvl` Home Manager settings that depend on
  the machine, including typed connector, layout, rotation and DPI options from
  `home/przvl/host.nix`.

## Scope and ownership

- Put user applications and per-user desktop behavior in
  `home/przvl/default.nix`.
- Put system-wide behavior that every Blix machine should have in the focused
  file under `modules/common/`; register new common modules in
  `modules/common/default.nix`.
- Put only machine-dependent settings in `hosts/<hostname>/default.nix`:
  hostname, `system.stateVersion`, hardware quirks, device-specific power
  workarounds, and host-specific networking tweaks.
- Put machine-dependent user settings in `hosts/<hostname>/home.nix`. Declare a
  typed option in `home/przvl/host.nix` and set it per host; do not branch on
  the hostname inside shared user configuration.
- Never duplicate common configuration into individual hosts. A future host
  should inherit a laptop, desktop or phone profile and contain only its facts and
  exceptions.
- Keep machine-class defaults in `profiles/`; override typed
  `blix.machine` capabilities in the host's system module for hardware exceptions.
  Use the inherited capabilities in shared user configuration, not hostname checks.
- Keep phone boot, SoC, firmware and storage details in the hardware layer.
  Prepare ordinary NixOS userspace without adding an unverified deployment host
  or guessing device facts. Register the phone host only after hardware support
  and its boot/update workflow have been verified.
- Never move generated hardware facts out of a host's
  `hardware-configuration.nix`.
- Keep package names inside the existing `with pkgs;` package lists. Do not add
  a package that a `programs.*`/`services.*` module or `fonts.packages` already
  installs.
- Reference executables in generated configuration by store path
  (`${pkgs.foo}/bin/foo`), never by bare name. A multi-command script should
  use `pkgs.writeShellApplication` with `runtimeInputs` instead.
- Keep the X11 session and display environment in `home/przvl/x11.nix`; keep
  host-specific connector names in `hosts/<hostname>/home.nix` rather than
  branching on hostnames in shared user configuration.
- Preserve `system.stateVersion` and `home.stateVersion`. Change either only as
  part of an explicit, researched state-version migration.
- Do not edit `flake.lock` unless the requested work includes changing or
  updating a flake input.
- Avoid broad formatting or structural rewrites when a focused edit is enough.
  Preserve unrelated user changes already present in the worktree.

## Working procedure

1. Inspect `git status` and the relevant configuration before editing.
2. For regressions, inspect recent commits and available system or user journal
   logs before selecting a fix. Prefer evidence from the running host over
   assumptions about service behavior.
3. Make the smallest declarative change that addresses the request. Do not add
   imperative setup steps when a NixOS or Home Manager option exists.
4. Review the diff for accidental changes and run the required validation.
5. Activate only a configuration that has evaluated successfully.
6. Commit and push the scoped result as described below.

## Validation

Always check the patch and evaluate every host the flake defines:

```bash
git diff --check
nix flake check
nix flake check --all-systems --no-build
```

The x86 profile check also evaluates the full ARM phone fixture. When an ARM
builder is available, realize that synthetic system with
`nix build .#checks.aarch64-linux.phone-system --no-link`; this checks userspace
composition, not OnePlus boot compatibility. Never activate that fixture.

`nix flake check` evaluates each entry in `nixosConfigurations`, so it covers
new hosts automatically. To evaluate a single host while iterating:

```bash
  nix eval .#nixosConfigurations.zen.config.system.build.toplevel.drvPath --raw
  nix eval .#nixosConfigurations.t490.config.system.build.toplevel.drvPath --raw
```

For changes that affect boot, login, the desktop session, systemd units,
packages, or generated files, also realize the full system closure:

```bash
  nix build .#nixosConfigurations.zen.config.system.build.toplevel --no-link
  nix build .#nixosConfigurations.t490.config.system.build.toplevel --no-link
```

Run narrower checks when they add confidence, such as inspecting an evaluated
option or using an application's configuration validator. Report any check that
could not be run and why; do not describe an unrun check as passing.

## Activation and recovery

Apply a verified configuration on the selected host with:

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
