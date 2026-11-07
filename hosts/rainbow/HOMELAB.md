# rainbow homelab

## Overview

[T3 Code](https://t3.codes) (`pingdotgg/t3code`, MIT, by T3 Tools Inc. /
Theo Browne's team) is an agent-harness control surface: it runs coding
agents on a server and lets you drive them from a desktop app, a web app
(`app.t3.codes`), or iOS/Android. It's already in nixpkgs as
`pkgs.t3code`. The project README states "We are very very early in this
project. Expect bugs." — plan accordingly.

The idea for rainbow is to give each agent role its own Incus instance,
with its own T3 server, so credentials, working copies, and blast radius
are isolated. The Mac (or the browser on my desk) is the client; it
pairs into each instance's T3 server and surfaces them as separate
"environments."

## Hardware

- **CPU**: Ryzen 5 7600X (6c/12t, Zen 4)
- **GPU**: RTX 4070 (12 GB VRAM) — single card, shared with games
- **RAM**: 32 GiB
- **Display**: Samsung Neo G9 57" (7680×2160, 240 Hz)

That GPU caps local inference at **`gpt-oss-20b` 4-bit (~12 GiB VRAM)**.
The 120b model is out. 32 GiB of system RAM is comfortable for Ollama +
k3s + a game, but tight once we start layering agent VMs on top; see
`STATUS.md` for the memory notes.

## Layout — roles & instances

Each instance gets its own Incus project and its own T3 server. "T3 per
instance" (vs one T3 on the host) is the deliberate choice: per-role
logins, sessions, and bearer tokens don't share a blast radius, and it
composes with the `agent` / `sealed` profiles already in
`hosts/common/incus.nix`.

| Instance | Role | Agent | Incus profile(s) | Repo mount | Notes |
|---|---|---|---|---|---|
| `arch` | Architect | Claude Code | `default`, `agent` | `/srv/dev/proj` read-only, plus writes to its own task file | Writes tasks only |
| `eng-042` | Engineer | Codex | `default`, `agent` | `/srv/dev/proj-eng-042`, read-write | One per task, deleted after merge |
| `sec-042` | Reviewer | Claude Code | `default`, `sealed` + a read-only disk device | `/srv/dev/proj-eng-042` mounted `readonly=true` | Enforced by the mount, not just by settings |
| `oc` | Second-opinion reviewer | OpenCode + gpt-oss | `default`, `agent` | Whichever worktree it's assigned | Only reaches `infer` on the bridge |
| `infer` | Model server | Ollama (or llama.cpp) | `default` — container, not VM, for GPU | None | Only reachable from `oc` |

Create the instances in their own Incus project
(`incus project create dev`) so they're separated from anything else on
the box. Use **VMs** (`--vm`) for the agent instances — a VM kernel
boundary is stronger than a container's. Use a **container** for `infer`
if it needs direct GPU access; VM GPU passthrough on a single-GPU
desktop that also plays games is more trouble than it's worth.

Earlier drafts of this doc said the client had to be a Mac. That's not
true — T3 has desktop, web, iOS, and Android clients. Any of them can
pair with `t3 pair` and show up as an environment. The Mac is still the
primary client here, but nothing forces it.

## Current Nix state (what's already landed)

Rainbow already has the base ready in `hosts/common/incus.nix`:

- `virtualisation.incus.enable = true` with a preseed
- `incusbr0` bridge on `10.80.0.1/24`, IPv4 NAT, no IPv6
- `default` storage pool: btrfs on a 100 GiB sparse loop file (instant
  CoW snapshots — the point of the disposable-machine workflow)
- Profiles:
  - `default` — eth0 nic + root disk
  - `agent` — stacks `limits.cpu = 4`, `limits.memory = 8GiB`, 30 GiB
    root disk cap
  - `sealed` — stacks last to strip `eth0` (sets its type to `none`)
- `dev` Incus project (shares profiles with the default project so
  `agent` / `sealed` are usable without redefining)
- `networking.nftables.enable = true` (Incus assertion)
- Host firewall on `incusbr0`: only UDP 53/67, TCP 53 (DHCP + DNS)
- `vcaaron` in the `incus-admin` group (root-equivalent on the host —
  same class as the podman docker socket)

And from `hosts/rainbow/system.nix`:

- `pkgs.t3code` installed on the host (the `t3` CLI + the desktop
  client, for pairing and triage from the rainbow seat itself)

Agent VM images are also declarative now:

- `hosts/rainbow/agents/arch/configuration.nix` — Architect VM
  (Claude Code + t3code).
- `hosts/rainbow/agents/eng-042/configuration.nix` — Engineer VM
  (Codex + t3code).
- `packages.x86_64-linux.{arch,eng-042}-image-{disk,metadata}` build
  the qcow2 + metadata tarball Incus needs for import, using the
  upstreamed `incus-virtual-machine` module in nixpkgs. The guest
  `incus-agent` is enabled in each module so `incus exec` works.

What's **not** yet in Nix, but will be in the follow-up PR:

- Agent modules for `eng-042`, `sec-042`, `oc`, `infer` (mirror
  arch's pattern).
- Tailscale module (if we go hybrid remote)
- Egress allowlist beyond DHCP/DNS (per-role; see Containment below)
- Secrets handling (`sops-nix` or `agenix`) for per-instance GitHub PATs
- Gamemode hook extension to pause `infer` during games (mirror the
  existing `ollama.service` stop/start)

## Containment stopgaps

- **Read-only reviewer mount.**
  `incus config device add sec-042 work disk source=/srv/dev/proj-eng-042 path=/work readonly=true`.
  The reviewer can read the diff and run tests, but can't write to the
  tree.
- **No SSH keys inside instances.** Don't mount `~/.ssh`. Give each
  instance a fine-grained GitHub PAT limited to one repo. Only `eng-042`
  gets push.
- **Snapshot before each task.**
  `incus snapshot create eng-042 before-impl`, restore with
  `incus snapshot restore` if the run goes sideways. btrfs CoW makes
  this cheap.
- **Egress allowlist.** Currently `hosts/common/incus.nix` only opens
  DHCP + DNS on the bridge; everything else is blocked. When we actually
  deploy the instances, extend the per-role allowlist (via Incus network
  ACLs or iptables rules on the bridge):
  - `arch`, `eng-042`, `sec-042`: `api.anthropic.com`, `api.openai.com`,
    `api.github.com`, `objects.githubusercontent.com`
  - `oc`: only the `infer` instance's bridge address + port
  - `infer`: no egress
  Incus ACL exact flags vary by version — verify against the Incus docs
  before relying on them.
- **Permission modes.** Keep Full access off. Engineer threads run
  Supervised or Auto-accept edits. Reviewer threads run Supervised.
- **Pin T3.** Run `t3 update <exact version>`, and don't let the
  background service move to a new release unattended. Under Nix,
  the docs say to update via Nix rather than `t3 update`.
- **T3 Connect.** T3 Code's docs don't tell you to avoid Connect — they
  describe it as a NAT-traversal relay with a 3-machine cap on the free
  tier. We're avoiding it on principle: no third-party relay in the
  loop. `t3 serve --lan` (or `--tailscale-serve` once Tailscale is in)
  is enough.

## Networking and client access

T3 Code's reachability modes are:

- `t3 serve --lan` — accepts LAN and tailnet connections; a one-time
  pairing link is all that gates other devices on the same network from
  joining. Each `t3 pair` invocation yields a fresh one-time link.
- `t3 serve --tailscale-serve` — Tailscale-fronted HTTPS. Preferred
  remote option once Tailscale is in the Nix config.

For now, pair the Mac over LAN. When I add Tailscale, I'll switch to
`--tailscale-serve` so the phone/laptop can reach the instances from
outside the house without opening ports.

Git stays the sync layer. The home box holds the worktrees; the Mac
pulls and pushes to the same remote. **One active writer per branch**,
across machines. If the Mac needs an environment while I'm away and
there's no Tailscale, a separate OrbStack NixOS machine is a fallback
client — but it does **not** get write access to the same branches.

## Model server (gpt-oss + OpenCode)

T3 Code supports OpenCode as one of its agents. OpenCode in turn can
point at any OpenAI-compatible endpoint, which is what Ollama / llama.cpp
expose on `infer`. The `oc` instance then reaches `infer` over the
bridge, with the egress ACL blocking everything else.

**Sizing**: given the 4070's 12 GB VRAM, `gpt-oss-20b` 4-bit is the
realistic ceiling. The 120b model is out. Check the model card at
install time for the current quant's actual memory requirements.

**Status**: Ollama still runs on the **host** today (`services.ollama`
with `ollama-cuda`, `CUDA_VISIBLE_DEVICES=0`), not inside `infer`. The
host's `gamemode` custom hook already stops `ollama.service` on game
start and restarts it on game end (`hosts/common/gaming.nix`), so the
GPU-contention problem is managed for now. Moving Ollama into `infer`
is deferred to a later PR; when we do it, we'll need:

- GPU passthrough into the container (not a VM — single-GPU + games
  makes VM passthrough painful).
- The gamemode hook extended to stop/start the `infer` container the
  same way it currently gates `ollama.service`.
- A decision on whether host Ollama goes away entirely or stays for
  non-agent use (CLI, embeddings, etc.).

**Caveats**: local open models are less reliable at tool use and at
following long specs than the hosted frontier models. Use `oc` first as
a second-opinion reviewer where a miss is cheap, before giving it
implementation work. The HOMELAB-doc-era claim that OpenCode "1.14.19+
is required for T3" didn't survive a re-read of the T3 docs; treat it
as unverified and check at install time.

## Suggested order

Already done:

- Incus base (`hosts/common/incus.nix`): bridge, pool, profiles, `dev`
  project, egress lockdown, `incus-admin` group.
- `pkgs.t3code` on the host.
- `arch` VM image declared in Nix (`hosts/agents/arch/configuration.nix`
  + `.#arch-image-disk` / `.#arch-image-metadata` flake outputs).
- Host Ollama + gamemode stop/start hook.
- Host k3s (still worth re-questioning whether it belongs on the gaming
  host — see `STATUS.md`).

Next (post-rebuild — see **MVP runbook** below):

1. Build and import the `arch` image: `nix build .#arch-image-disk
   .#arch-image-metadata && incus image import ... --alias arch-vm`.
2. `incus launch arch-vm arch --vm -p default -p agent` in the `dev`
   project.
3. Inside `arch` (as the `agent` user): `t3 serve --lan`, `t3 pair`,
   connect from the Mac client.
4. Confirm the Mac sees the environment and can run a plan-only task
   against this repo.

After that:

5. Build + launch `eng-042` (scaffolding already in place — see the
   runbook subsection below). Add a writable worktree mount per task,
   log Codex in with a per-instance fine-grained GitHub PAT. Snapshot
   before each task; restore after to confirm the rollback works.
6. `hosts/rainbow/agents/sec-042/configuration.nix` with the reviewer
   package set. Launch with `readonly=true` on the disk device.
   **Verify the mount refuses writes from inside** — don't trust the
   setting without testing.

Later:

7. Stand up `infer` (GPU container) and `oc` (VM). Revisit the egress
   ACL to allow only `oc` → `infer`. Extend the gamemode hook to pause
   `infer`.

## MVP runbook: `arch` instance from our own flake image

We build the VM image from `hosts/agents/arch/configuration.nix` via
`nixos-generators` and import it into Incus. Nothing about the VM
contents (packages, user, flakes-on state) lives outside git; the
image is bit-for-bit reproducible and flake.lock-pinned.

### Build the image (host)

```bash
# Build the qcow2 disk and metadata tarball in one shot.
nix build --print-out-paths \
  .#arch-image-disk .#arch-image-metadata
# Prints two store paths:
#   /nix/store/.../arch-image-disk    (contains nixos.qcow2)
#   /nix/store/.../arch-image-metadata (contains metadata.tar.xz)
```

### Import into Incus

```bash
# Import both pieces under a stable alias. Re-importing with the same
# alias replaces the old image. Both the qcow and tarball names carry
# a version suffix, so we glob rather than hardcode.
DISK=$(nix build --no-link --print-out-paths .#arch-image-disk)
META=$(nix build --no-link --print-out-paths .#arch-image-metadata)
incus image import "$META"/tarball/*.tar.xz "$DISK"/*.qcow2 --alias arch-vm
```

### Launch

```bash
# Switch into the dev project (preseeded in hosts/common/incus.nix).
incus project switch dev

# Launch from our image, stacking the agent resource limits. The agent
# profile sets security.secureboot=false, so the unsigned NixOS kernel
# boots cleanly.
incus launch arch-vm arch --vm -p default -p agent

# Wait until the guest agent is reachable (~45-60s on first boot).
incus exec arch -- true

# Drop into a login shell as the pre-created `agent` user.
incus exec arch -- su - agent
```

The image already has:

- `claude-code` and `t3code` on `$PATH`
- `vim`, `git`, `jq`
- Nix flakes enabled system-wide
- A `wheel` member `agent` user (`sudo` is passwordless; change the
  initial password immediately)
- SSH disabled — the only ingress is T3's bearer

### Start T3 and pair

Inside the VM, as `agent`:

```bash
# Start the server on LAN only — no third-party relay.
t3 serve --lan

# In a second shell on the VM, print a one-time pairing link.
incus exec arch -- su - agent -c 't3 pair'
```

Back on the T3 client (Mac / web / phone):

1. Add an environment using the pairing link.
2. Sign in to Anthropic inside the environment. This login lives inside
   the `arch` VM, not on the host.
3. When ready to point Claude Code at this repo, mount it read-only:
   ```bash
   incus config device add arch proj disk \
     source=/home/vcaaron/projects/nixos path=/srv/dev/proj readonly=true
   ```

### Rollback

```bash
incus snapshot create arch baseline
# ...run a task...
incus snapshot restore arch baseline
```

### Re-rolling the image

When the arch `configuration.nix` changes:

```bash
# Rebuild and re-import under the same alias.
nix build .#arch-image-disk .#arch-image-metadata
incus image import <paths> --alias arch-vm

# Existing instances don't update themselves. Either launch fresh ones
# from the new alias, or:
incus delete -f arch && incus launch arch-vm arch --vm -p default -p agent
```

## MVP runbook: `eng-042` instance

Same shape as `arch`, with one extra device: a writable worktree mount.
The agent profile's 30 GiB disk cap applies, so very large worktrees want
a dedicated disk pool rather than the built-in rootfs.

```bash
# 1. Build + import (same flow as arch, different alias).
DISK=$(nix build --no-link --print-out-paths .#eng-042-image-disk)
META=$(nix build --no-link --print-out-paths .#eng-042-image-metadata)
incus image import "$META"/tarball/*.tar.xz "$DISK"/*.qcow2 \
  --alias eng-042-vm

# 2. Launch (dev project, agent profile).
incus project switch dev
incus launch eng-042-vm eng-042 --vm -p default -p agent

# 3. Attach a writable worktree. Create the worktree on the host first;
#    one-writer-per-branch still applies, so this VM owns the branch
#    while it's mounted.
HOST_WT=/home/vcaaron/projects/nixos-worktrees/eng-042-task
git -C /home/vcaaron/projects/nixos worktree add "$HOST_WT" -b eng-042/task-001
incus config device add eng-042 work disk source="$HOST_WT" path=/work

# 4. Snapshot a known-good baseline before the first task.
incus snapshot create eng-042 baseline

# 5. Shell in and start T3 as the agent user; log into Codex inside the VM.
incus exec eng-042 -- su - agent -c 't3 serve --lan'
# second shell:
incus exec eng-042 -- su - agent -c 't3 pair'
```

Rollback between tasks:

```bash
incus snapshot restore eng-042 baseline
```

When a task is done, detach the worktree and either merge it back on the
host or discard it:

```bash
incus config device remove eng-042 work
git -C /home/vcaaron/projects/nixos worktree remove "$HOST_WT"
```

## Open questions / TODO for the next PR

- **Auto-start the homelab on rainbow boot.** Right now the full
  "build image → `incus image import` → `incus launch` → attach mounts
  → `t3 serve` in a zellij pane → `t3 pair`" flow is entirely
  imperative, and nothing comes back up after a reboot. The k3s module
  on rainbow already handles its own auto-boot; want the same for the
  agent instances. Options to explore:
  - Declarative Incus instances via an extended preseed (if upstream
    supports it) or a systemd oneshot on rainbow that runs
    `incus launch <alias> <name> -p ... --no-wait` with idempotency.
  - `t3 service install` inside each VM so `t3 serve` comes up as a
    user systemd service, not something that dies when you close the
    terminal pane.
  - Mounts (worktrees, nix-store, blitz repo) baked into an Incus
    *profile* per role, so `incus launch` with that profile stacks
    them automatically instead of a `config device add` sequence.
- NixOS vs Debian/Ubuntu for the Incus VM images? NixOS gives us
  flake-based reproducibility and a single config language; non-NixOS
  is faster to get a shell on. Leaning NixOS for `arch`/`eng-042`/
  `sec-042`, Debian for `infer` (GPU container ergonomics).
- Secrets: `sops-nix` vs `agenix` for per-instance GitHub PATs.
- Tailscale now or deferred? LAN pairing is fine while I'm at the desk;
  Tailscale unlocks the phone/laptop case.
- Pinning strategy for `pkgs.t3code` given upstream's "very very early"
  warning. Probably a dedicated flake input tracking a known-good tag.
- Per-instance T3 install path — Nix inside NixOS VMs, `curl` installer
  inside Debian. Standardize one or document both.
- **Writable shared Nix store once lane VMs start building Rust.**
  Read-only `/nix/store` bind mount works for arch (plan-only), but
  lane VMs compiling the Blitz workspace will want to add paths. Needs
  a decision: per-VM overlay store (safer), or writable shared store
  (simpler, accepts lateral-movement risk inside the `dev` project).

## References

- https://t3.codes
- https://github.com/pingdotgg/t3code
- https://github.com/pingdotgg/t3code/blob/main/docs/user/install.md
- https://github.com/pingdotgg/t3code/blob/main/docs/user/remote-access.md
- `hosts/common/incus.nix` — base infrastructure this plan builds on
- `hosts/rainbow/STATUS.md` — gaming-perf doc; cross-references the
  GPU-contention / k3s baseline questions
