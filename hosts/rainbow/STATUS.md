# rainbow — status & roadmap

Rainbow is the primary Linux dev + gaming workstation, and since
2026-11 also hosts the agent homelab (`HOMELAB.md`). Last reviewed
2026-11-08.

## Hardware

- **Board:** MSI MS-7D78
- **CPU:** AMD Ryzen 5 7600X (Zen 4, 6c/12t, AM5)
- **GPU:** NVIDIA GeForce RTX 4070 (Ada Lovelace, 12 GB VRAM)
- **RAM:** 32 GiB (30.5 GiB usable — ~1.5 GiB reserved, likely iGPU framebuffer)
- **iGPU:** AMD Raphael (Ryzen 7000-series integrated — currently unused)
- **Disk:** single NVMe, 882 GiB ext4 root + 33.6 GiB swap partition
- **Display:** 57" Samsung (assumed Odyssey Neo G9 57" — 7680×2160 @ 240 Hz,
  VRR/FreeSync Premium Pro, HDR; needs DP 2.1 for full rate)

## Current configuration

- **OS:** NixOS 26.11, `linuxPackages_zen` (7.2.x), KDE Plasma 6.8 on
  Wayland, SDDM
- **GPU driver:** `nvidia-open`, stable branch, modesetting on,
  `powerManagement.enable = true` (Wayland stability workaround)
- **Audio:** PipeWire with 32-bit ALSA support for Steam
- **Gaming stack:** Steam + gamescope session, gamemode, MangoHud,
  protonup-qt, Lutris, xpadneo (Xbox controller)
- **Services:** Ollama (CUDA, `gemma4:12b`, 32k context), k3s, Incus
  (agent VMs), Podman with Docker-compat socket
- **Power:** suspend/hibernate disabled (always-on desktop); CPU on
  `amd_pstate` active, EPP `balance_performance`

## Applied tuning

Gaming (`system.nix`, `common/gaming.nix`):

- **Kernel:** zen (BORE scheduler) for mixed gaming + desktop load.
- **gamemode:** renice, screensaver inhibit, NVIDIA PowerMizer max
  performance while a game runs; start/end hooks stop and restart Ollama
  to free VRAM.
- **NVIDIA/Proton env:** 10 GB GL shader disk cache, `PROTON_ENABLE_NVAPI=1`
  (DLSS Frame Generation), `nvidia-vaapi-driver` for NVDEC video decode,
  KWin VRR cursor delay for the Neo G9 taskbar flicker.
- **sysctl:** `swappiness=10`, `vfs_cache_pressure=50`, smaller dirty
  ratios (10/5), larger network buffers.
- **Swap:** zstd zram at 50% of RAM, ahead of the disk swap partition.
- **Audio:** PipeWire quantum 512 (min 32, max 2048), ~10 ms round trip.

Host housekeeping (`common/system.nix`):

- Nix GC weekly (`--delete-older-than 14d`), `min-free` 10 GiB /
  `max-free` 50 GiB, store optimise on a timer, weekly fstrim.

Homelab load on the host (2026-11-08, `HOMELAB.md` "Housekeeping"):

- **Memory was the bottleneck.** The desktop stuttered with 2.5 GiB
  available, zram full, ~10 GiB on disk swap, and ~14% of time fully
  stalled on memory (PSI). Agent VMs held ~6 GiB host RAM each while
  using ~1.7 GiB: guest page cache in memfd-backed RAM (virtiofs needs
  shared memory), which the host can't reclaim and KSM can't merge.
  - **Fix:** the `balloon` Incus profile turns on free-page reporting,
    and each guest drops clean page cache every 10 minutes
    (`agent-vm.nix`). Measured on `test`: 5.4 GiB → 2.0 GiB host RSS.
- **CPU:** agent VMs run at `limits.cpu.priority = 4` (default 10), so
  the desktop, games and k3s win under contention. Their 4-vCPU caps
  together cover all 12 threads.
- **Disk:** the Incus pool (100 GiB loop file) went 92 → 43 GiB by
  pruning superseded images and VM Nix stores. The host root went
  88% → 79% by removing stale Rust `target/` dirs (Polar 49 GiB, argus
  15 GiB), anonymous podman volumes and an unused `~/.ollama` model
  store. Steam (309 GiB) is the biggest remaining consumer.
- `jr` is benched: stopped and not autostarted.

## Open candidates

Ordered by impact-per-effort for this rig. The 7680×2160 panel dominates:
the 4070's 12 GB VRAM is tight at native res in modern AAA, so upscaling
and VRAM discipline matter more than raw latency tuning.

1. **Pause agent VMs during games:** extend the gamemode hooks to
   `incus pause` the running agents and resume them after (TODO in
   `HOMELAB.md`; deferred while Ollama agents are unused).
2. **Gamescope per-game launch options:** a documented baseline for
   AAA titles:
   ```
   gamescope -W 7680 -H 2160 -r 240 --adaptive-sync \
     --hdr-enabled --mangoapp --expose-wayland -- %command%
   ```
   For VRAM-tight games, render at half-width and upscale:
   `-w 3840 -h 2160 -W 7680 -H 2160 -F fsr`.
3. **`__GL_MaxFramesAllowed=1`** for lower input lag in competitive
   titles (per game, not global).
4. **Root mount options:** `noatime` (and maybe `commit=120`) for less
   write amplification. It lives in `hardware-configuration.nix`, which
   is generator output, so it would go in `system.nix` as an override.
5. **Rust build dirs:** `cargo-sweep` or a periodic `cargo clean` across
   `~/projects`. Stale `target/` dirs reached 64 GiB.
6. **MangoHud config** checked in via home-manager, for consistent
   frame-time, 1% low and GPU power measurements.
7. **Proton-GE:** record the version in use and the games that need it,
   so rebuilds don't regress.
8. **k3s on the gaming host:** ~0.7 GiB RSS at idle. Still worth
   re-asking whether it belongs here, or gating it behind a flag.
9. **iGPU (Raphael)** for the compositor, leaving the 4070 to games.
   Advanced; not before the simpler wins.

NVAPI note: it occasionally breaks kernel anti-cheat titles; turn it off
per game if needed.

## Unknowns to capture before tuning

- **Monitor model confirmation:** is it the Odyssey Neo G9 57" (G95NC)? The
  full 240 Hz / 7680×2160 pipe needs DP 2.1 — the 4070 Founders is DP 1.4a
  (DSC gets us to 240 Hz, but confirm the EDID is negotiating what we expect
  via `kscreen-doctor -o` or `wayland-info`).
- **EXPO status:** is DDR5 running at rated speed? `sudo dmidecode -t memory`
  will confirm. Zen 4 is very memory-bandwidth sensitive.
- **PBO / Curve Optimizer:** 7600X undervolt via PBO CO (-20 to -30
  typical). BIOS-side, not Nix.
- **NVMe model & thermals:** shader stutter correlates with slow NVMe under
  sustained write.
- **Game mix:** competitive FPS vs AAA single-player changes which knobs
  matter.
