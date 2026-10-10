# blix contributor guide

This repository is the declarative NixOS configuration for Blix machines and
the Home Manager configuration for the `przvl` user. It is structured for
multiple hosts; `zen`, `t490` and the prepared OnePlus 6T `phone` are defined.
The phone has not yet been installed or physically boot-verified. Choose
validation according to the scope and risk rules in the Validation section.

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
- `tests/` checks laptop, desktop and ARM phone defaults, environment replacement,
  overrides and display hotplug behavior. Its synthetic fixtures must never be
  activated or flashed.
- `profiles/laptop.nix`, `profiles/desktop.nix` and `profiles/phone.nix` compose
  the shared foundation, select system and user environments, and supply inherited
  defaults. Every host imports one profile. Profiles describe capabilities
  independently of CPU architecture.
- `modules/boot/uefi.nix` supplies optional PC boot defaults. Shared common
  modules and the phone profile do not select a bootloader or device kernel.
- `modules/common/default.nix` aggregates the shared system foundation: boot,
  locale, Nix, networking, users, command-line packages, capabilities and Home
  Manager integration. It does not select a desktop or user applications.
- `modules/desktop/` supplies the optional X11/OXWM session, desktop services,
  fonts and system utilities. Profiles select it explicitly.
- `modules/common/machine.nix` declares typed machine capabilities and passes
  user capabilities to Home Manager. Behavior must not branch on the machine type.
- `modules/hardware/` separates keyboard, mouse, touchpad, lid/power and
  Bluetooth policy. `default.nix` imports session-independent power and Bluetooth
  policy; `x11.nix` composes input policy for the desktop environment.
  `keyboards/mechanical.nix` owns the USB-specific Cmd/Super mapping; modifier
  swaps must never be applied to every keyboard.
- `hosts/<hostname>/default.nix` owns configuration specific to that machine
  and composes a machine profile, its generated hardware module, and genuinely
  device-specific settings.
- `hosts/<hostname>/hardware-configuration.nix` contains detected hardware;
  change it only when the machine's hardware or generated configuration
  intentionally changes.
- `hosts/phone/hardware.nix` imports the pinned Mobile NixOS `oneplus-fajita`
  hardware/boot layer. `bootstrap.nix` and `bootstrap.pub` isolate temporary
  USB networking and key-only SSH; `bootstrap-system.nix` replaces the desktop
  for the small installation image. No generated phone hardware file exists yet.
- `home/przvl/base.nix` owns shared user identity, state version and capability
  options. `default.nix` selects the workstation environment for laptops and
  desktops; `phone.nix` independently selects the phone's applications and
  environment without importing the workstation composition. The phone currently
  selects the regular OXWM desktop and standard applications through its own
  imports.
- `home/przvl/environments/oxwm.nix` composes reusable X11 user services, helpers,
  packages and desktop settings. It does not select the browser or terminal.
- `home/przvl/config/` owns the Blix-derived OXWM, Picom, Xfe, Neovim,
  Neofetch, and helper-script configuration.
- `home/przvl/hardware/` declares typed user capabilities and display options;
  `display.nix` owns the display helper package and hotplug service. The X11
  display environment remains in `home/przvl/x11.nix`. `bluetooth.nix` binds the
  Blueman pairing agent to the manual Blix session without a tray dependency.
- `hosts/<hostname>/home.nix` composes machine-dependent user settings and
  imports `display.nix` for connector, layout, rotation and DPI facts when using X11.

## Scope and ownership

- Select workstation applications in `home/przvl/default.nix` and phone
  applications and behavior in `home/przvl/phone.nix` or focused modules it
  imports. Share reusable program configuration without importing the workstation
  composition into the phone. Keep `base.nix` free of session and application policy.
- Changes to a reusable module affect every composition that imports it. Put
  behavior intended only for the phone in its user composition or a module only
  that composition imports.
- Put system-wide behavior that every Blix machine should have in the focused
  file under `modules/common/`; register new common modules in
  `modules/common/default.nix`.
- Keep optional desktop system behavior in `modules/desktop/` and reusable OXWM
  user-session composition in `home/przvl/environments/oxwm.nix`. Select these
  explicitly from profiles and user roots; do not branch on hostnames or machine
  type to choose an environment.
- When replacing the phone session, change both the system environment selection
  in `profiles/phone.nix` and the user modules in `home/przvl/phone.nix`. Replace
  X11-specific application, appearance and `blix.display` settings together.
- Put only machine-dependent settings in `hosts/<hostname>/default.nix`:
  hostname, `system.stateVersion`, hardware quirks, device-specific power
  workarounds, and host-specific networking tweaks.
- Put machine-dependent user settings in `hosts/<hostname>/home.nix` or a focused
  file it imports, such as `display.nix`. Declare typed hardware options in
  `home/przvl/hardware/` and set them per host; do not branch on hostnames.
- Keep peripheral behavior in `modules/hardware/`; device-specific keyboard
  rules belong in `modules/hardware/keyboards/` and match the device identity.
  Keep tmux as an unconfigured package without a Blix layout helper or config.
- Select refresh rates from the display's advertised modes at the configured
  resolution; preserve per-output selection instead of globally capping mirrors.
  Keep Bluetooth defaults capability-based and device pairing state on the host.
- Never duplicate common configuration into individual hosts. A future host
  should inherit a laptop, desktop or phone profile and contain only its facts and
  exceptions.
- Keep machine-class defaults in `profiles/`; override typed
  `blix.machine` capabilities in the host's system module for hardware exceptions.
  Use the inherited capabilities in shared user configuration, not hostname checks.
- Keep phone boot, SoC, firmware and storage details in the hardware layer.
  Keep the prepared phone host's physical verification status explicit. Verify
  device facts and the boot/update workflow before deployment; evaluation does
  not prove bootability. Discover unobserved display connectors at runtime.
  Phone kernel/initrd updates need separately reviewed Android boot images;
  `nixos-rebuild switch` updates userspace without writing phone partitions.
- Never unlock, erase, format, flash, sideload a partition-writing payload, or
  manipulate phone partitions without first showing the exact operation and
  obtaining explicit user approval. Never run generated flashing scripts as
  part of evaluation, builds, tests or an ordinary rebuild.
- Never move generated hardware facts out of a host's
  `hardware-configuration.nix`.
- Keep package names inside the existing `with pkgs;` package lists. Do not add
  a package that a `programs.*`/`services.*` module or `fonts.packages` already
  installs.
- Reference executables in generated configuration by store path
  (`${pkgs.foo}/bin/foo`), never by bare name. A multi-command script should
  use `pkgs.writeShellApplication` with `runtimeInputs` instead.
- Keep the X11 session and display environment in `home/przvl/x11.nix`; keep
  host-specific connector names in `hosts/<hostname>/display.nix` rather than
  branching on hostnames in shared user configuration.
- Preserve `system.stateVersion` and `home.stateVersion`. Change either only as
  part of an explicit, researched state-version migration.
- Do not edit `flake.lock` unless the requested work includes changing or
  updating a flake input.
- Avoid broad formatting or structural rewrites when a focused edit is enough.
  Preserve unrelated user changes already present in the worktree.
- Keep this guide and `README.md` aligned when module ownership or environment
  selections change.

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

Use lightweight validation for very small, isolated, reversible changes limited
to documentation, comments, or presentation-only application preferences, such
as Neovim absolute versus relative line numbering:

- Review the scoped diff and run `git diff --check`.
- For an application preference, run a relevant syntax/configuration check or
  directly verify the affected behavior.
- Do not run full flake checks, all-host/all-system evaluations, or full system
  closure builds for these edits. A presentation preference being in a generated
  file does not by itself require those checks.
- Report the focused validation performed and briefly state why it is sufficient.

Use the full validation below for changes to Nix logic or module composition,
packages, services, boot/login, session startup, networking/security, hardware,
or application/script logic beyond an isolated presentation preference. Also
use it when there is concrete uncertainty about wider impact; a small diff in
these areas does not qualify for the lightweight exception.

For changes outside that exception, check the patch and evaluate every host:

```bash
git diff --check
nix flake check
nix flake check --all-systems --no-build
```

The x86 profile check also evaluates the full ARM phone fixture. When an ARM
builder is available, realize that synthetic system with
`nix build .#checks.aarch64-linux.phone-system --no-link`; this checks userspace
composition, not OnePlus boot compatibility. Never activate that fixture.

Tests describe the current profile selections. When intentionally changing a
profile's environment, update its fixture settings and expectations, including
the phone checks in `tests/machine-profiles.nix` and `tests/session-settings.nix`.
Preserve the shared-foundation and environment-replacement coverage in
`tests/environment-composition.nix`.

`nix flake check` evaluates each entry in `nixosConfigurations`, so it covers
new hosts automatically. To evaluate a single host while iterating:

```bash
  nix eval .#nixosConfigurations.zen.config.system.build.toplevel.drvPath --raw
  nix eval .#nixosConfigurations.t490.config.system.build.toplevel.drvPath --raw
  nix eval .#nixosConfigurations.phone.config.system.build.toplevel.drvPath --raw
```

For changes outside the lightweight exception that affect boot, login, the
desktop session, systemd units, packages, or generated files, also realize the
full system closure:

```bash
  nix build .#nixosConfigurations.zen.config.system.build.toplevel --no-link
  nix build .#nixosConfigurations.t490.config.system.build.toplevel --no-link
```

Run narrower checks when they add confidence, such as inspecting an evaluated
option or using an application's configuration validator. Report any check that
could not be run and why; do not describe an unrun check as passing.

The real phone requires an ARM builder for its full closure. The separate
`packages.x86_64-linux.phone-bootstrap-images` cross-compiles the small bootstrap
on an x86 builder. See README.md for build and approval gates; neither image
building nor the `phone-hardware` integration check proves physical bootability.

## Activation and recovery

Select the flake output that matches the target machine. For `zen`, apply a
verified configuration with:

```bash
sudo nixos-rebuild switch --flake .#zen
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
