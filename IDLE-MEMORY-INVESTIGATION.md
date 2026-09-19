# Blix idle-memory investigation

Date: 2026-09-19 (America/New_York)

Scope: read-only investigation of the live ASUS Zenbook (`zen`), the Blix
repository at `d8efb53`, and the Minarch repository at `f954da4`. No services
were disabled, no packages were installed, and no NixOS rebuild was run for
this investigation.

## Executive summary

The observed number is not a 700–900 MiB Blix desktop-process overhead.

The first live Fastfetch sample reported `2.56 GiB / 30.82 GiB`. It was taken
inside this investigation while the Codex agent was running. The Codex wrapper
and its code-mode child accounted for approximately **588 MiB PSS** combined
(about 0.57 GiB of physical memory after shared pages are apportioned). Removing
that workload from the sample puts the same machine near **1.97 GiB** by the
same rough accounting, which is consistent with the reported normal Blix range
of roughly 2.0–2.2 GiB.

Fastfetch is not reporting the sum of application RSS. In this run it matched
`MemTotal - MemAvailable` within rounding:

```text
32,320,356 kB - 29,651,448 kB = 2,670,812 kB = 2.55 GiB
```

That number includes active file cache, kernel accounting, unreclaimable
kernel memory, anonymous process memory, and Linux's availability heuristic.
It does not mean that 2.55 GiB is pinned application memory. The machine had
about 11.5 GiB of file cache, 1.16 GiB of reclaimable slab, zero swap use, and
zero current memory pressure.

Nix-specific resident processes are small relative to the alleged gap:

* `nix-daemon`: 38.5 MiB RSS; its 156.9 MiB cgroup value included about
  137.6 MiB of file cache and about 10.9 MiB of anonymous memory.
* `nsncd`: 7.8 MiB RSS.
* No Nix build/evaluation children remained resident.

The Zenbook also does not expose the same memory baseline as the Minarch
measurement machine. BIOS e820 reported 31.476 GiB of usable physical ranges
before kernel reservations, while `/proc/meminfo` exposed 30.823 GiB. The
kernel reported 891,312 kB reserved at boot. This is hardware/firmware/kernel
accounting, not a Blix user-session process, and the available data cannot
assign all of it specifically to the GPU.

The current evidence therefore supports this conclusion:

1. The current investigation's Codex process explains roughly 0.57 GiB of the
   apparent difference in the live sample.
2. The normal Blix X11/audio/session stack is in the low hundreds of MiB of
   RSS and roughly 140 MiB PSS for the selected user-session processes.
3. NixOS-specific resident services add tens of MiB, not 700–900 MiB.
4. A substantial part of the displayed number is reclaimable/cache or kernel
   accounting rather than pinned application memory.
5. An exact 1.3 GiB Minarch-vs-Blix comparison is not possible without the
   Minarch machine's live `/proc`, kernel, firmware, and service measurements.

No actionable Blix configuration problem large enough to explain 700–900 MiB
was found.

## Measured baseline

The baseline was captured at approximately 13:30–13:47 EDT after 15 hours of
uptime. The initial requested commands reported:

```text
OS:       NixOS 26.11 (Zokor) x86_64
Host:     ASUS Zenbook S 14 UX5406SA_UX5406SA
Kernel:   Linux 6.18.52
CPU:      Intel Core Ultra 7 258V
Uptime:   approximately 15 hours
Fastfetch: Memory 2.55–2.56 GiB / 30.82 GiB
```

Current `/proc/meminfo` values at the final snapshot:

| Field | Value | Interpretation |
|---|---:|---|
| `MemTotal` | 32,320,356 kB / 30.82 GiB | RAM exposed to Linux |
| `MemFree` | 15,103,020 kB / 14.40 GiB | Completely unused pages |
| `MemAvailable` | 29,651,448 kB / 28.28 GiB | Kernel estimate available without swapping |
| `Buffers` | 1,846,048 kB / 1.76 GiB | Buffer cache |
| `Cached` | 12,056,384 kB / 11.50 GiB | File cache, mostly reclaimable |
| `SReclaimable` | 1,188,764 kB / 1.16 GiB | Reclaimable slab |
| `SUnreclaim` | 261,716 kB / 255.6 MiB | Unreclaimable or difficult-to-reclaim slab |
| `Slab` | 1,450,480 kB / 1.42 GiB | `SReclaimable + SUnreclaim`; do not add again |
| `AnonPages` | 591,036 kB / 577.2 MiB | Anonymous process memory and related pages |
| `Active(file)` | 989,616 kB / 966.4 MiB | Recently used file pages; not equivalent to pinned RAM |
| `Inactive(file)` | 12,837,620 kB / 12.24 GiB | Cold file cache, readily reclaimable |
| `Mapped` | 330,804 kB / 323.1 MiB | Overlaps process/file/anonymous categories |
| `Shmem` | 75,332 kB / 73.6 MiB | Shared-memory/tmpfs accounting |
| `Unevictable` | 67,104 kB / 65.5 MiB | Pages not currently reclaimable |
| `Mlocked` | 0 kB | No mlocked pages |
| `KernelStack` | 5,232 kB / 5.1 MiB | Kernel task stacks |
| `PageTables` | 7,936 kB / 7.8 MiB | Page-table memory |
| `SecPageTables` | 3,336 kB / 3.3 MiB | Secondary page tables |
| `Percpu` | 6,208 kB / 6.1 MiB | Per-CPU allocations |
| `VmallocUsed` | 83,196 kB / 81.2 MiB | Virtual address space; not a direct RAM-use number |
| `SwapTotal` | 8,079,868 kB / 7.71 GiB | zram swap capacity |
| `SwapFree` | 8,079,868 kB / 7.71 GiB | Entire swap capacity free |

The important relationships are:

```text
MemTotal - MemAvailable                         2,670,812 kB = 2.55 GiB
MemTotal - (MemFree + Buffers + Cached + SReclaimable)
                                                    2,128,044 kB = 2.03 GiB
Buffers + Cached                                 13,902,432 kB = 13.26 GiB
AnonPages + SUnreclaim + Active(file) + Unevictable
                                                    1,908,896 kB = 1.82 GiB
```

These are deliberately not treated as additive categories. `Active(file)` is
part of the file-cache picture, `Mapped` overlaps process mappings, and slab is
already represented by its reclaimable/unreclaimable components. The difference
between the two first equations is the kernel's conservative availability
reserve and other accounting effects.

`free -h` showed approximately 14 GiB free, 14 GiB buff/cache, 28 GiB
available, and no swap used. Memory PSI was zero for the 10-second, 60-second,
and 300-second windows. There was no OOM or sustained reclaim/kswapd evidence
in the current boot journal.

## Largest userspace consumers

RSS is useful for finding candidates but double-counts shared libraries. PSS
from `/proc/*/smaps_rollup` was used for readable user processes. Root-owned
process PSS was not readable under the current permissions, so their RSS is
shown only as an upper-bound indicator.

| Process | RSS | PSS | Finding |
|---|---:|---:|---|
| Codex wrapper (`codex --yolo`) | 565.9 MiB | 559.8 MiB | Active investigation workload, not idle desktop |
| Codex code-mode child | 31.5 MiB | 27.9 MiB | Same workload |
| Xorg | 91.3 MiB | 79.2 MiB | Main expected X server cost |
| WirePlumber | 34.4 MiB | 20.7 MiB | Audio session manager |
| `st` | 16.6 MiB | 10.9 MiB | One terminal |
| PipeWire | 15.8 MiB | 9.5 MiB | Audio server |
| PipeWire Pulse bridge | 14.8 MiB | 8.6 MiB | Pulse compatibility endpoint |
| OXWM | 11.1 MiB | 5.8 MiB | Window manager |
| Picom | 7.1 MiB | 2.8 MiB | Compositor |
| `xclip` | 4.2 MiB | 3.1 MiB | Holding the current PNG clipboard selection |
| `dconf-service` | 6.3 MiB | 1.5 MiB | Blix/NixOS desktop preference service |
| `xss-lock` | 6.7 MiB | 1.3 MiB | Suspend/lock helper |
| clipmenud wrapper | 4.4 MiB | 1.5 MiB | Event-driven text clipboard history |
| Blix hotplug monitor group | 9.5 MiB | 2.7 MiB | Shell plus two `udevadm` monitors |

The Codex wrapper and child together were about 587.7 MiB PSS. Subtracting
that from the 2.55 GiB Fastfetch sample gives roughly 1.97 GiB before trying
to account for shared pages, the terminal, and cache movement. This is why the
live sample must not be described as an idle Blix baseline.

The selected non-Codex Blix session processes were approximately 234 MiB RSS
and 140.5 MiB PSS. That is not a complete physical-memory total, but it shows
that X11, OXWM, Picom, PipeWire, WirePlumber, clipboard, locking, and hotplug
helpers are not individually large enough to explain the reported gap.

## Service and cgroup accounting

Running system services included NetworkManager, wpa_supplicant, polkit,
RealtimeKit, journald, logind, systemd-oomd, systemd-timesyncd, systemd-udevd,
`nsncd`, and `nix-daemon`. Running user services included the Blix lock,
clipboard, hotplug, and Picom units; the user D-Bus broker; dconf; PipeWire;
PipeWire-Pulse; and WirePlumber.

Useful cgroup values were:

| Cgroup | `memory.current` | Relevant breakdown |
|---|---:|---|
| `system.slice` | 443.1 MiB | Includes system service memory and cache |
| `system.slice/nix-daemon.service` | 156.9 MiB | ~137.6 MiB file, ~10.9 MiB anonymous, ~8.4 MiB kernel/slab |
| `user@1000.service` | 69.5 MiB | User manager and user services |
| Audio user-service subtree | 47.0 MiB | WirePlumber ~26.1, PipeWire ~11.7, Pulse bridge ~8.1 MiB |
| Blix app service subtree | 16.2 MiB | Clipboard, hotplug, lock, Picom, dconf, D-Bus socket |
| `session-1.scope` | ~14.2 GiB | ~12.7 GiB file cache, ~507 MiB anonymous, ~1.08 GiB reclaimable slab |

The very large `session-1.scope` value is not a 14 GiB userspace leak. It is
mostly inactive file cache charged to the session cgroup. `systemd-cgtop` and
raw `memory.current` values must be interpreted with `memory.stat`; they include
page cache and kernel cache, not just resident private process memory.

## Nix/NixOS-specific memory

`nix-daemon.service` had been running since boot, with one resident daemon PID
and nine tasks. It had no lingering `nix-store`, evaluator, builder, or other
child process. Its RSS was 38.5 MiB. Systemd reported a cgroup current value of
156.9 MiB and a peak of 251.3 MiB; the cgroup's `memory.stat` shows that most of
the current value is file cache, not daemon-private anonymous memory.

The only Nix timers were `nix-optimise.timer` and `nix-gc.timer`; timers are not
resident worker processes. The current `nix-optimise` and garbage-collection
jobs were not running.

`nsncd` is NixOS's name-service cache daemon. It was 7.8 MiB RSS and 3.9 MiB
cgroup memory. Together, Nix daemon plus `nsncd` are a measurable Blix/NixOS
difference, but not a 700–900 MiB difference. Recent Nix evaluations and system
inspection commands also populate the Nix store page cache; that cache is
reclaimable and can make cgroup/file-cache readings look much larger than the
daemon's resident footprint.

## Kernel memory

The global kernel categories were:

```text
Slab:          1,416.5 MiB
  SReclaimable: 1,160.9 MiB
  SUnreclaim:     255.6 MiB
KernelStack:       5.1 MiB
PageTables:        7.8 MiB
SecPageTables:     3.3 MiB
Percpu:             6.1 MiB
VmallocUsed:      81.2 MiB (virtual address accounting, not direct RAM)
```

The largest category is reclaimable slab, not pinned application memory. The
255.6 MiB `SUnreclaim` value is the largest clearly non-reclaimable kernel
category observed, but it cannot be assigned to a subsystem from the available
permissions.

`slabtop` and `/proc/slabinfo` both returned permission denied. The
`/sys/kernel/slab` directories were visible but their per-cache counters were
also unreadable. Consequently, this investigation can quantify total
reclaimable/unreclaimable slab but cannot name the largest individual caches
without privileged access. No cache-dropping operation was performed.

## Intel GPU and NPU

The live hardware uses:

```text
00:02.0 Intel Core Ultra 200V Arc Graphics 130V/140V GPU -> xe
00:0b.0 Intel Core Ultra 200V NPU                         -> intel_vpu
```

Relevant observations:

* The `xe` module code size was 4,005,888 bytes (about 3.82 MiB).
* The `intel_vpu` module code size was 348,160 bytes (about 0.33 MiB).
* The display GPU was runtime-active because Xorg owns `/dev/dri/card0`.
* No process owned `/dev/dri/renderD128` at the sample time.
* The NPU was runtime-suspended and its module reference count was zero.
* `CmaTotal` was zero; there was no large CMA reservation reported.
* The GPU PCI BARs (16 MiB and 256 MiB) and NPU BARs (32 MiB and 4 KiB) are
  MMIO address windows, not proof of host-RAM consumption.
* The kernel logged that it reduced the compressed framebuffer size because of
  available stolen memory. It did not report a large host-memory allocation.

The DRM debugfs directory was not readable, and no `intel_gpu_top`/`drm_info`
tool was installed. Therefore live xe GEM/GTT buffer totals could not be read
without privileged/debugfs access. The available evidence does not show an
active NPU allocation or a hundreds-of-MiB userspace graphics allocation.
Xorg's measured 79.2 MiB PSS is the visible graphics/session cost.

The Zen-specific NixOS hardware configuration enables Intel NPU support and
sets xe panel-replay/self-refresh workarounds, but those settings do not
explain a 700–900 MiB idle process overhead. The machine's hardware baseline
does differ from the Minarch measurement machine.

## Firmware and physical-memory accounting

The machine is marketed/configured as 32 GiB, but the kernel exposed
30.823 GiB as `MemTotal`. The boot journal's BIOS e820 usable ranges sum to
31.476 GiB, and the kernel reported:

```text
Memory: 32025880K/33005404K available (... 891312K reserved, 0K cma-reserved)
```

This establishes roughly 0.5 GiB of nominal-vs-BIOS-usable difference and a
large additional boot-time reserved/kernel-accounting component. The exact
reserved-region ownership cannot be determined from the redacted
`/proc/iomem` output or the unprivileged DRM interfaces. This is a
Zenbook/firmware/kernel baseline and should not be attributed to NixOS desktop
configuration.

## zram and swap

Blix configured `/dev/zram0` as a 7.7 GiB zstd swap device. It was effectively
empty:

```text
logical swap used: 0
zram data:         4 KiB
zram compressed:   64 bytes
zram total:        20 KiB
```

Zram is not consuming hundreds of MiB while idle and is not the cause of the
reported difference.

## tmpfs, shmem, and logging

Filesystem usage was small:

| Location | Used |
|---|---:|
| `/run` tmpfs | about 7 MiB |
| `/dev/shm` | 8 KiB |
| `/run/user/1000` | about 176 KiB |
| `/run/wrappers` | about 864 KiB |

`journalctl --disk-usage` reported 33.8 MiB on disk. That is not a RAM
measurement, and there was no evidence of journald consuming a large resident
buffer. Global `Shmem` was 73.6 MiB, but the inspected resident mappings were
small: the Xorg shared memfd was mapped as a 16 MiB virtual region with zero
resident pages in the observed maps, PipeWire's inspected memfds were tiny, and
`/dev/shm` itself was nearly empty. Shared memory is therefore not a
700–900 MiB explanation.

## Blix versus Minarch runtime differences

The repositories intentionally describe nearly the same X11 session. Minarch
does not define a complete system-service baseline: it preserves the Arch
machine's pre-existing networking and system services and explicitly says it
does not disable them. Therefore the table identifies differences in declared
ownership and the live Blix cost, not an exact cross-machine subtraction.

| Component | Blix | Minarch | Estimated idle RAM impact | Evidence / confidence |
|---|---|---|---:|---|
| Manual X11 + OXWM + st + Picom | Present | Present | Xorg ~79 MiB PSS; OXWM ~6; Picom ~3 | Same session design; high confidence |
| PipeWire + WirePlumber + Pulse bridge | Present | Present | ~40 MiB combined PSS on this Zenbook; ~47 MiB user cgroup | Same declared audio stack; high confidence |
| Lock, clipboard, hotplug helpers | Present | Present | Selected group ~10 MiB RSS / ~6 MiB PSS excluding X/audio | Same units and purpose; high confidence |
| `nix-daemon` | Running | Absent from Minarch | 38.5 MiB RSS; likely much less unique PSS | Live `ps`/cgroup; high confidence |
| `nsncd` | Running | No Nix equivalent | 7.8 MiB RSS | Live process; high confidence |
| `dconf-service` | Running due `programs.dconf` | Not part of Minarch manifest | 6.3 MiB RSS / ~1 MiB cgroup | Live process and Blix module; high confidence |
| systemd-oomd | Running | Not enabled by Minarch | 5.7 MiB RSS / 1.7 MiB cgroup | Live service; high confidence |
| systemd-timesyncd | Running | Minarch leaves time/network ownership to Arch | 8.0 MiB RSS / 4.2 MiB cgroup | Live service; cross-machine impact uncertain |
| RealtimeKit | Running | Not explicitly packaged by Minarch | 3.2 MiB RSS / 1.1 MiB cgroup | Live service; small |
| TLP | Active-exited startup unit | Not part of Minarch | No resident daemon | Live status shows no long-running process |
| NetworkManager, wpa_supplicant, D-Bus, polkit | Running | Minarch expects/preserves equivalents | NM ~25 MiB RSS, wpa ~12 MiB, shared system daemons | Not a valid Blix-only difference; Minarch leaves baseline unchanged |
| xe GPU / intel_vpu NPU | xe active; NPU suspended | Different Minarch hardware/kernel baseline | No measured large NPU allocation; driver code <5 MiB | Hardware differs; DRM debugfs unavailable |

The only direct Blix/NixOS additions large enough to notice individually are
the Nix daemon and its small companion services. Their measured resident cost is
in the tens of MiB. Package count, Nix store size, fonts, Firefox/Codex
installation, compiler tools, and Neovim plugins do not consume idle RAM unless
their processes are running or their files are cached.

## Potential optimizations

| Optimization | Estimated saving | Functionality lost | Confidence | Recommendation |
|---|---:|---|---|---|
| Measure after closing the Codex agent and other workload processes | ~0.57 GiB in this sample | None; only closes the active workload | High | Do this for fair benchmarking |
| Wait for recent Nix/evaluation file cache to cool naturally | Potentially hundreds of MiB in the displayed/cache categories, not pinned RAM | None | High that cache is reclaimable; low exact saving | Prefer this measurement practice; do not drop caches |
| Disable `nix-daemon`/NixOS Nix infrastructure | At most tens of MiB unique; 38.5 MiB RSS upper bound for daemon | Nix daemon-backed commands/builds and name caching | High | Do not recommend |
| Disable dconf | A few MiB unique; 6.3 MiB RSS upper bound | dconf-managed desktop settings | High | Do not recommend |
| Disable systemd-oomd, timesyncd, or RealtimeKit | Each is only a few MiB RSS/cgroup | OOM policy, time synchronization, or real-time audio scheduling | High | Do not recommend |
| Disable Picom | About 2.8 MiB PSS plus unmeasured compositor buffers | Transparency/compositor effects | High for process cost | Optional only if effects are unwanted; not a RAM fix |
| Remove active `xclip` ownership | About 3.1 MiB PSS | Current image clipboard ownership | High | Not worthwhile |
| Disable xe/NPU support | No measured large saving; NPU was suspended and driver code is ~0.33 MiB | GPU display acceleration or NPU availability | Low for unmeasured driver allocations | Do not recommend |

There is no measured low-risk Blix configuration change that would save
700–900 MiB while preserving the current functionality. Dropping caches or
disabling kernel services would make the displayed number smaller temporarily
or remove useful functionality, but would not establish a better idle design.

## Conclusion

On this Zenbook, a clean Blix session with no Codex/development workload is
expected to land around **1.9–2.1 GiB** on Fastfetch, with ordinary variation
from page cache, terminal state, X11 buffers, and kernel reclaim decisions. The
reported 2.0–2.2 GiB is therefore plausible. The 1.3 GiB Minarch number is not
an apples-to-apples target because the Minarch measurement came from different
hardware and an Arch system whose base services are explicitly outside the
repository's ownership.

The current live evidence does not identify a 700–900 MiB Blix/NixOS desktop
leak or an actionable configuration mistake. The largest observed differences
are measurement workload (the active Codex process), reclaimable file/slab
cache, and Zenbook firmware/kernel accounting. A privileged follow-up could
split individual slab caches and xe GEM/GTT allocations, but the unprivileged
measurements already show that neither Nix daemon processes, zram, tmpfs, nor
the NPU explains the claimed gap.
