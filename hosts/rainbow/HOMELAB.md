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
- `networking.nftables.enable = true` (Incus assertion)
- Host firewall on `incusbr0`: only UDP 53/67, TCP 53 (DHCP + DNS)
- `vcaaron` in the `incus-admin` group (root-equivalent on the host —
  same class as the podman docker socket)

What's **not** yet in Nix, but will be in the follow-up PR:

- `pkgs.t3code` on the host (for the CLI + client)
- Per-instance T3 install path (Nix inside the instance if it's NixOS,
  `curl` installer otherwise)
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

- Incus base (`hosts/common/incus.nix`): bridge, pool, profiles, egress
  lockdown, `incus-admin` group.
- Host Ollama + gamemode stop/start hook.
- Host k3s (still worth re-questioning whether it belongs on the gaming
  host — see `STATUS.md`).

Next PR:

1. Add `pkgs.t3code` to the host config so the CLI and desktop client
   are available on rainbow itself.
2. `incus project create dev` and switch to it.
3. Launch `arch` as a NixOS VM in that project
   (`incus launch images:nixos/unstable arch --vm -p default -p agent`).
   Install `claude-code` and `t3` inside (via Nix if NixOS, else the
   installer).
4. `t3 serve --lan` in `arch`; `t3 pair` and connect from the Mac.
5. Confirm the Mac can see the environment and run a plan-only task.

After that:

6. Add `eng-042` with a worktree mount
   (`incus config device add eng-042 work disk source=... path=/work`)
   and a Codex login scoped to its own fine-grained GitHub PAT. Run one
   small task, snapshot before, restore after — confirm the rollback
   actually works.
7. Add `sec-042` with `readonly=true` on the disk device. **Verify
   the mount refuses writes from inside** — don't trust the setting
   without testing.

Later:

8. Stand up `infer` (GPU container) and `oc` (VM). Revisit the egress
   ACL to allow only `oc` → `infer`. Extend the gamemode hook to pause
   `infer`.

## Open questions / TODO for the next PR

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

## References

- https://t3.codes
- https://github.com/pingdotgg/t3code
- https://github.com/pingdotgg/t3code/blob/main/docs/user/install.md
- https://github.com/pingdotgg/t3code/blob/main/docs/user/remote-access.md
- `hosts/common/incus.nix` — base infrastructure this plan builds on
- `hosts/rainbow/STATUS.md` — gaming-perf doc; cross-references the
  GPU-contention / k3s baseline questions
