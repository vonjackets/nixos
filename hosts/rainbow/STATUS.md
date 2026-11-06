# rainbow — status & roadmap

Rainbow is the primary Linux dev + gaming workstation.

## Hardware

- **Board:** MSI MS-7D78
- **CPU:** AMD Ryzen 5 7600X (Zen 4, 6c/12t, AM5)
- **GPU:** NVIDIA GeForce RTX 4070 (Ada Lovelace, 12 GB VRAM)
- **RAM:** 32 GiB (30.5 GiB usable — ~1.5 GiB reserved, likely iGPU framebuffer)
- **iGPU:** AMD Raphael (Ryzen 7000-series integrated — currently unused)
- **Display:** 57" Samsung (assumed Odyssey Neo G9 57" — 7680×2160 @ 240 Hz,
  VRR/FreeSync Premium Pro, HDR; needs DP 2.1 for full rate)

## Current configuration (snapshot)

- **OS:** NixOS 26.11, kernel 6.18.44, KDE Plasma 6.7.4 on Wayland, SDDM
- **GPU driver:** `nvidia-open` kernel modules, stable driver,
  `modesetting.enable = true`, `powerManagement.enable = true` (Wayland
  stability workaround)
- **Audio:** PipeWire with 32-bit ALSA support for Steam
- **Gaming stack:** Steam + gamescope session, gamemode, MangoHud,
  protonup-qt, Lutris, xpadneo (Xbox controller)
- **Extras:** Bluetooth on, Ollama (CUDA) as systemd service, k3s module,
  Podman with Docker-compat socket
- **Power:** suspend/hibernate disabled (always-on desktop)

## Gaming optimization — areas to improve

Ordered by impact-per-effort **for this specific rig**. The 7680×2160 panel is
the dominant constraint: the 4070's 12 GB VRAM is tight at native res in
modern AAA, so upscaling and VRAM discipline matter more than raw latency
tuning. For competitive titles (which are usually CPU-bound at lower
resolutions anyway), latency knobs still pay off.

Nothing here is applied yet — these are candidates.

### 1. Kernel selection
- **Current:** 6.18.44 (likely `linuxPackages_latest` given the version).
- **Opportunity:** `linuxPackages_zen` for BORE scheduler — Zen 4 benefits
  noticeably from BORE's interactive-task boosting in mixed gaming+desktop
  workloads. CachyOS kernel is the aggressive option (sched_ext, more tuning)
  but needs the CachyOS flake input.
- **Risk:** `nvidia-open` module must build against chosen kernel — Zen
  usually tracks mainline fast enough that this is fine, but verify with
  `nixos-rebuild build` before switching.

### 2. CPU governor & gamemode tuning
- **Current:** `programs.gamemode.enable = true` with no custom config.
- **Opportunity:** explicit `programs.gamemode.settings` block: set governor
  to `performance` during games, renice to `-10`, enable `ioprio`, and
  (NVIDIA) set `nv_powermizer_mode = 1` for max perf while the game is live.

### 3. NVIDIA perf & VRAM knobs
- **Current:** `powerManagement.enable = true` (for Wayland stability),
  nothing else.
- **Opportunity:**
  - `__GL_MaxFramesAllowed=1` for lower input lag in competitive titles.
  - Larger shader cache (very helpful on a 4070 at this res):
    `__GL_SHADER_DISK_CACHE=1`, `__GL_SHADER_DISK_CACHE_SIZE=10737418240` (10 GB).
  - DLSS Frame Generation via Proton — set `PROTON_ENABLE_NVAPI=1` and
    `PROTON_HIDE_NVIDIA_GPU=0` globally (Steam → Launch Options or
    `environment.sessionVariables`). This is the single biggest win on a
    7680×2160 panel with a 4070 — turns VRAM-limited stutter into playable
    frame times in DLSS3-capable games.
  - `nvidia-vaapi-driver` for hardware video decode (Discord/Firefox) so the
    GPU isn't CPU-decoding streams while you game.
- **Risk:** NVAPI enablement occasionally breaks anti-cheat — flip it per
  game if you play kernel-AC titles.

### 4. Gamescope per-game launch options
- **Current:** `gamescopeSession.enable = true`, no documented defaults.
- **Opportunity:** with a 7680×2160/240 Hz VRR+HDR panel, gamescope earns its
  keep. Suggested baseline for AAA titles:
  ```
  gamescope -W 7680 -H 2160 -r 240 --adaptive-sync \
    --hdr-enabled --mangoapp --expose-wayland -- %command%
  ```
  For VRAM-tight games, render at half-width and upscale:
  `-w 3840 -h 2160 -W 7680 -H 2160 -F fsr` (or `-F nis`).
  Competitive titles → render at 3840×1620 or similar for CPU headroom and
  let gamescope upscale.

### 5. I/O and memory tuning
- **Current:** default sysctl, 32 GiB RAM, swap partition on disk.
- **Opportunity:** `vm.swappiness = 10`, `vm.vfs_cache_pressure = 50`,
  net buffer bumps for online play. 32 GiB is comfortable for games but tight
  if Ollama + k3s + a chunky game are all resident — consider `zram-generator`
  (compressed swap in RAM) to beat the on-disk swap partition under
  shader-compile spikes.

### 6. Shader & asset storage layout
- **Current:** single ext4 root on NVMe, swap partition on same disk.
- **Opportunity:** confirm Steam library is on NVMe (it should be given
  single-disk layout). Add `noatime,commit=120` to root mount options for
  less write amplification. At 7680×2160 Steam's shader pre-caching can hit
  tens of GB — keep an eye on `/var/lib/nvidia-settings` and
  `~/.cache/nvidia`.

### 7. Audio latency
- **Current:** default PipeWire quantum.
- **Opportunity:** lower quantum (e.g. `default.clock.quantum = 512`,
  `default.clock.min-quantum = 32`) for lower audio latency in competitive
  titles. Headset-dependent.

### 8. Proton & compatibility
- **Current:** protonup-qt installed; nothing pinned.
- **Opportunity:** document the Proton-GE version in use and the one or two
  games that benefit from it, so rebuilds don't regress.

### 9. Controller & peripheral polish
- **Current:** xpadneo + headsetcontrol installed.
- **Opportunity:** confirm xpadneo rumble/trigger support per controller,
  consider `services.hardware.openrgb` if RGB control is wanted.

### 10. Observability
- **Current:** MangoHud + nvtop installed.
- **Opportunity:** a repeatable MangoHud config (frame-time graph, 1% lows,
  GPU power) checked in via home-manager so measurements are consistent
  across sessions.

## Unknowns to capture before tuning

- **Monitor model confirmation:** is it the Odyssey Neo G9 57" (G95NC)? The
  full 240 Hz / 7680×2160 pipe needs DP 2.1 — the 4070 Founders is DP 1.4a
  (DSC gets us to 240 Hz, but confirm the EDID is negotiating what we expect
  via `kscreen-doctor -o` or `wayland-info`).
- **EXPO status:** is DDR5 running at rated speed? `sudo dmidecode -t memory`
  will confirm. Zen 4 is very memory-bandwidth sensitive; stock JEDEC speeds
  leave meaningful FPS on the table.
- **PBO / Curve Optimizer:** 7600X loves an undervolt via PBO CO
  (-20 to -30 typical). BIOS-side change — not Nix — but worth tracking here.
- **NVMe model & thermals:** single-disk ext4; shader stutter correlates with
  slow NVMe under sustained write.
- **Game mix:** competitive FPS vs AAA single-player changes which knobs
  matter.

## Non-gaming notes

- Ollama runs with `CUDA_VISIBLE_DEVICES=0`. If a game and a model are
  loaded at the same time, they'll fight over the 4070's 12 GB — consider a
  systemd drop-in to pause the ollama service during gamemode sessions, or
  constrain it to CPU when a game is running.
- k3s is enabled — baseline CPU/RAM load is non-trivial on a 6-core CPU.
  Confirm it's wanted on the gaming host or gate it behind a flag.
- iGPU (Raphael) is currently unused. Could be assigned to desktop
  compositor and leave the 4070 fully for games — advanced setup, not
  recommended until the simpler wins are in.
