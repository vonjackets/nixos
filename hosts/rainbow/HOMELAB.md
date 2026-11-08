# rainbow homelab

## Overview

[T3 Code](https://t3.codes) (`pingdotgg/t3code`, MIT, by T3 Tools Inc. /
Theo Browne's team) is an agent-harness control surface: it runs coding
agents on a server and lets you drive them from a desktop app, a web app
(`app.t3.codes`), or iOS/Android. It's already in nixpkgs as
`pkgs.t3code`. The project README states "We are very very early in this
project. Expect bugs." — plan accordingly.

The idea for rainbow is to give each agent role its own Incus VM, with
its own T3 server, so credentials, working copies, and blast radius are
isolated. The Mac (or the browser on my desk) is the client; it pairs
into each instance's T3 server and surfaces them as separate
"environments."

## Hardware

- **CPU**: Ryzen 5 7600X (6c/12t, Zen 4)
- **GPU**: RTX 4070 (12 GB VRAM) — single card, shared with games
- **RAM**: 32 GiB
- **Display**: Samsung Neo G9 57" (7680×2160, 240 Hz)

That GPU caps local inference at roughly a 20B-class model at 4-bit
(~12 GiB VRAM); `jr` runs `gemma4:12b` (~8 GB). The
120b-class models are out. 32 GiB of system RAM is comfortable for
Ollama + k3s + a game, but tight once agent VMs are layered on top (each
`agent` profile VM is capped at 8 GiB); see `STATUS.md` for the memory
notes. Plan on two or three VMs running at once, not all of them.

## Roles

**I am the lead.** I'm the maintainer of every project these agents work
on. I set the goal and I merge. There is no architect agent; that was
the first cut's `arch` role, and it's gone.

**The point of this homelab is to see agents coordinate and get work
done without me in the loop.** I hand a goal to `sec`; the team plans,
splits, builds, reviews and documents it among themselves; I watch every
session live in my host T3 and step in only at the gates below. (This
replaced an earlier "only the lead dispatches" rule on 2026-11-07.)

Rules for every role:

1. **The team runs itself between the gates.** `sec` coordinates: it
   turns my goal into tasks and hands them to `eng` and `jr` over T3
   links (see **Team** below). `eng` hands `jr` the low-risk pieces
   directly and checks its output. Questions go up the chain, `jr` →
   whoever gave it the task, `eng` → `sec`. Only what `sec` can't
   settle comes to me.
2. **Gates that stay with me:** merging to `main`, anything applied to a
   cluster or the cloud, new attack surface (ports, egress, credentials),
   and changing what the product is for. An agent that reaches one stops
   and says so in its thread.
3. **Each role owns its lane's files, and its own docs.** It edits only
   its lane's paths, and updates the documentation for its own work in
   the same branch. A change needed in another lane's files goes to that
   lane's agent as a task (via `sec`), not as an edit.
4. **Links point down only:** `sec` → `eng-app`, `sec` → `jr`,
   `eng-app` → `jr`. A driven agent acts with its own credentials and
   egress, so `jr` (no internet, no keys) never drives anyone. The host
   enforces the direction at the network as well as in T3.

| Role | Image | Does | Harness | Writes | Reads | Egress |
|---|---|---|---|---|---|---|
| **Lead** (me) | — (host) | Assigns tasks, answers questions, merges, deploys | — | `main` checkout, cluster, cloud | everything | — |
| **Backend/systems engineer** | `eng` | Writes code: features, fixes, infra sources | Claude Code, Codex | its lane clone at `/work` | my main checkout at `/lead`, `readonly=true` (the clone's origin) | frontier APIs, GitHub |
| **DevSecOps engineer** (my right hand) | `sec` | Owns the delivery process end to end: pipeline, hardening, config, process docs, findings, reviews, and task proposals for other roles (see below) | Claude Code, Codex | its lane clone at `/work` | my main checkout at `/lead` (all lanes' branches, handoffs, requests); optionally a branch at `/review`; both `readonly=true` | frontier APIs, GitHub |
| **Technical writer** | `doc` | Updates the docs: manuals, docs build, operator guide | Claude Code, Codex | its lane clone at `/work` | my main checkout at `/lead`, `readonly=true` (the clone's origin) | frontier APIs, GitHub |
| **Junior engineer** | `jr` | Lowest-risk tasks I forward: small fixes, lint/fmt cleanups, test scaffolding, second-opinion reviews where a miss is cheap | OpenCode + local model | its own clone at `/work` | my main checkout at `/lead`, `readonly=true` (the clone's origin) | `infer` only |
| **Model server** | `infer` (container) | Serves the local model to `jr` | Ollama or llama.cpp | — | — | none |

Notes on the table:

- **Image vs instance.** An image is a role, and an instance is a role
  working one lane. If two engineering lanes are active at once, launch
  two instances from `eng-vm`, e.g. `eng-app` and `eng-view`. Instances
  are long-lived per lane, not per task: the first cut's `eng-042` per
  task naming is gone. Snapshot each instance before every task, so that
  "throw away a bad run" is a `snapshot restore`, not a delete.
- **Harnesses are an experiment.** The frontier roles have both Claude
  Code and Codex installed, so I can compare them per thread from T3.
  Only a harness that's logged in inside that VM can be used, so having
  a package installed doesn't spread any credential. Once a winner per
  role is clear, drop the other from that role's `configuration.nix`.
- **`jr`'s model is `gemma4:12b`** (Q4_K_M, ~8 GB, tool-capable). OpenCode
  points at an Ollama OpenAI-compatible endpoint. Its config is baked into
  the image, limited to that one local model.
- **Reviews.** `sec` is the reviewer. A second opinion from `jr` is
  cheap and optional. It never replaces `sec`'s review.

### `sec`: the DevSecOps engineer

`sec` is more than a reviewer. It's my right hand for making sure the
work actually carries out the vision. It writes, and what it writes is
the delivery process itself.

**Goals**

1. Maximize DSO process performance.
2. Maximize customer/user satisfaction, and the customer is me, the lead.

**Core questions it keeps answering**

1. Is the DSO process optimized?
2. Is the lead happy?
3. Is the system/product easy to use and operate?
4. What does it cost to release and maintain the product?
5. What is the ROI on process improvements?
6. What is the ROI on alternative processes, tools, or products?

**Responsibilities**

- Provide leadership and vision for the changes needed to adopt DevOps
  practices.
- Work across the roles ("organizational units") to remove barriers to
  communication and information exchange: stale handoffs, unanswered
  requests, lanes blocked on each other.
- Determine which tools and processes best solve long-term needs.
- Improve processes to better serve the lead.
- Find the obstacles each role faces.

**What it writes** (in its own lane clone, on its own branch)

- Pipeline, CI, config, and hardening changes. This is the lane it owns
  in the project, the same as Blitz lane D.
- **Findings**: an observation, the evidence for it, its cost or risk,
  and a recommendation with an ROI estimate. These answer the core
  questions above and are written for me to read and decide on.
- **Tasks for `eng` and `jr`**, started directly in their environments
  over its T3 links, each with a clear done-condition. It reviews what
  comes back before calling the goal done. If a task needs a decision
  from me (a gate, rule 2), it says so and waits.
- **A run log** in its lane: what my goal became, who did what, what it
  reviewed, what it would change about the process next time. This is
  the record of how the team performed.

**What it can see.** My main checkout is mounted read-only at `/lead`,
so `git show lane/<x>:<path>` reads every lane's branch, handoff and
request without writing to any of them. Seeing across lanes is what
makes "remove barriers" and "find obstacles" possible. Without this
mount it would only see its own lane.

It sees a lane's branch only once **I've fetched it into my checkout**
(`git -C ~/projects/blitz fetch ../blitz-app lane/app:lane/app`). Lane
work lives in the lane clones until then. That fetch is also what
"hand it to `sec` for review" means in practice.

**What it can't do.** It can't write outside its own lane clone, can't
merge, and can't apply to a cluster. Those are mine.

### Team: how the agents coordinate

```
            me (host T3: watches all three, owns the gates)
             │ goal
             ▼
            sec ──────────────┐   Claude Code; coordinates and reviews
             │ link           │ link
             ▼                ▼
          eng-app ─────────▶ jr   eng-app: Claude Code; jr: OpenCode + gemma4:12b
                  link
```

**Mechanism.** Each arrow is a `t3 environment link`, created in the
upper VM. Agents in that VM's T3 sessions get T3's tools for the linked
environment: list projects, start a thread with a chosen provider and
model, message it, read its replies. A busy thread gets a message as its
next turn. Each link:

- has **only `orchestration:read` and `orchestration:operate`** scopes,
  so threads only. No terminal, filesystem, settings, provider or token
  scopes; T3's default pairing grants all of those.
- runs at **`auto-accept-edits`** access. The driven agent edits its own
  lane clone without asking anyone, but nothing runs at full access.
- goes over a **loopback forwarder** in the upper VM
  (`http://127.0.0.1:4730x`, from `homelab.agentVm.t3Peers`). T3 only
  links over plain http to loopback or Tailscale, so the link token
  crosses the host-internal bridge unencrypted. That's acceptable on a
  bridge with anti-spoofing; Tailscale is the upgrade.
- **expires after 30 days** (current ones: 2026-12-08). Renew with the
  link runbook below.

**Picking models.** T3 projects have no default model, so whoever starts
a thread names one. `eng-app`/`sec`: provider `claudeAgent`, e.g.
`claude-sonnet-5-5` or `claude-opus-5-5`. `jr`: provider `opencode`,
model `ollama/gemma4:12b` (the only one it offers).

**Verified 2026-11-07:** `sec`'s Claude found `jr` over its link, started
a thread on gemma, waited, and relayed `PONG`, in about 35s, with no
files changed.

**Kicking off a goal** (paste into a new `sec` thread, with
`claudeAgent`):

```
You coordinate a three-agent team for the lead (me) who is watching and primarily responsible for goal setting, maintaining alignment with project vision, and architecutre.

Your linked environments: eng-app (backend/systems engineer, Claude Code,
lane clone /work on lane/app) and jr (junior engineer, OpenCode with
ollama/gemma4:12b, lane clone /work on lane/jr, lowest-risk work only).
Read /lead/AGENTS.md and /lead/docs/lanes/README.md first. Team rules on
top of those: links point down (you -> eng-app, you -> jr, eng-app -> jr);
questions go up; each agent edits only its lane and updates the docs for
its own work; stop at the gates (merge, cluster/cloud apply, new
ports/egress/credentials, product direction). 

The project's AGENTS.md and other docs specify rules that every agent should adhere to. If one is not present or unclear, ask me and I will clarify.

```

### Mapping onto Blitz

Blitz (`~/projects/blitz`) already runs this shape as swimlanes
(`docs/lanes/README.md`). Each lane has one checkout and one branch, and
owns explicit paths:

| Blitz lane | Role / instance | Lane clone mounted at `/work` |
|---|---|---|
| Lead | me, on the host | `~/projects/blitz` (main) |
| A. Cloud path (paused) | `eng`, when it resumes | `../blitz-cloud` |
| B. Implementation | `eng` → `eng-app` | `../blitz-app` |
| C. Engine and model | `eng` → `eng-view` | `../blitz-view` |
| D. DevSecOps | `sec` | `../blitz-hardening` (+ `~/projects/blitz` at `/lead`, read-only) |
| E. User manual | `doc` | `../blitz-manual` |
| (none yet) | `jr` | a clone per forwarded task, on a branch I name |

Each lane's kickoff message (`docs/lanes/KICKOFF.md`) is the first thing
I paste into that instance's T3 thread. The lanes' rules (stage by path,
handoff file, "if blocked, write the question and stop") already match
the rules above. Blitz's lane D brief describes D as "the pipeline,
hardening, review". The broader `sec` role described here (findings,
process ROI, proposed tasks) is a change to that brief, so it belongs in
Blitz's `docs/lanes/D-hardening-review.md`. That's a lead edit, made in
the Blitz repo, not here.

## Current Nix state (what's already landed)

Rainbow already has the base ready in `hosts/common/incus.nix`:

- `virtualisation.incus.enable = true` with a preseed
- `incusbr0` bridge on `10.80.0.1/24`, IPv4 NAT, no IPv6
- `default` storage pool: btrfs on a 100 GiB sparse loop file (instant
  CoW snapshots — the point of the disposable-machine workflow)
- Profiles:
  - `default` — eth0 nic + root disk
  - `agent` — stacks `limits.cpu = 4`, `limits.memory = 8GiB`, 30 GiB
    root disk cap, `security.secureboot = false`
  - `sealed` — stacks last to strip `eth0` (sets its type to `none`)
- `dev` Incus project (shares profiles with the default project so
  `agent` / `sealed` are usable without redefining)
- `networking.nftables.enable = true` (Incus assertion)
- Host firewall on `incusbr0`: only UDP 53/67, TCP 53 (DHCP + DNS) to
  the host; DHCP pool `.100`–`.254`, `.2`–`.99` for pinned instances
- `vcaaron` in the `incus-admin` group (root-equivalent on the host —
  same class as the podman docker socket)

From `hosts/rainbow/system.nix`:

- `pkgs.t3code` on the host (the `t3` CLI and desktop client, for pairing
  and triage from the rainbow seat itself)

Agent VM images:

- `hosts/common/agent-vm.nix` — shared base every role imports. It sets
  up the guest `incus-agent`, a locked-password `agent` user (uid 1000),
  flakes, SSH off, a guest firewall that opens only T3's port (3773), and
  **`t3-serve.service`**: `t3 serve --lan --no-browser --port 3773 /work`
  as `agent`. It restarts on failure and starts at boot after
  `incus-agent` has mounted `/work`. Options: `homelab.agentVm.{role,
  description, workDir, t3Port}`.
- `hosts/rainbow/agents/{eng,sec,doc,jr}/configuration.nix` — one per
  role: the role name, a description, and its harness packages.
- `packages.x86_64-linux.<role>-image-{disk,metadata}` for each role in
  `flake.nix`'s `roles` list. They build the qcow2 and metadata tarball
  for `incus image import`.

Not yet in Nix:

- `infer` (Debian container with GPU passthrough; not a NixOS agent image)
- Tailscale module (if we go hybrid remote)
- Egress allowlist beyond DHCP/DNS (per-role; see Containment below)
- Secrets handling (`sops-nix` or `agenix`) for per-instance GitHub PATs
- Gamemode hook extension to pause `infer` during games (mirror the
  existing `ollama.service` stop/start)

## Containment stopgaps

- **Read-only cross-lane mounts.** `sec` reads my main checkout (`/lead`)
  and any branch under review (`/review`)
  through disk devices with `readonly=true`:
  `incus config device add sec lead disk source=<main checkout> path=/lead readonly=true`,
  `incus config device add sec review disk source=<lane clone> path=/review readonly=true`.
  It can read every lane and run tests, but it can't write to those trees.
  **Verify a write from inside fails** before trusting it.
- **No SSH keys inside instances.** Don't mount `~/.ssh`. Give each
  instance a fine-grained GitHub PAT limited to one repo. A role that
  pushes gets push only to its lane's branch pattern, and I merge.
- **Snapshot before each task.**
  `incus snapshot create <instance> before-<task>`. If the run goes
  sideways, restore with `incus snapshot restore`. btrfs CoW makes this
  cheap.
- **Egress.** `hosts/common/incus.nix` limits what instances can reach
  **on the host** (DHCP and DNS only, plus `jr` → the Ollama proxy). It
  does not limit **forwarded** traffic: through the bridge's NAT, the
  instances can reach the internet. Per role:
  - `jr`: **no internet** (done, in `hosts/rainbow/homelab.nix`). An
    nftables forward chain drops any new connection from `10.80.0.50`.
  - `eng`, `sec`, `doc`: still open. The target allowlist is
    `api.anthropic.com`, `api.openai.com`, `api.github.com`,
    `objects.githubusercontent.com`. Hostname allowlists need either a
    DNS-aware filter or Incus ACLs. The exact Incus ACL flags vary by
    version, so check them against the docs.
  - `infer`: no egress (pull models through the host, then copy them in).
- **Pinned addresses.** Rules that key on a source IP (`jr`'s) need that
  IP pinned (`ipv4.address` on the instance's `eth0`) and outside the
  DHCP pool (`.100`–`.254`). They also assume no other instance claims
  it. Turning on `security.ipv4_filtering` on every instance's NIC would
  enforce that; it's a TODO.
- **Permission modes.** Keep Full access off. Engineer and writer threads
  run Supervised or Auto-accept edits. Review threads run Supervised. `jr`
  runs Supervised until it has earned more.
- **Pin T3.** Under Nix, T3 is updated through Nix, not `t3 update`. The
  version is whatever `flake.lock` pins, and images only change when
  rebuilt.
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

Git stays the sync layer. The home box holds the lane clones; the Mac
pulls and pushes to the same remote. **One active writer per branch**,
across machines. If the Mac needs an environment while I'm away and
there's no Tailscale, a separate OrbStack NixOS machine is a fallback
client — but it does **not** get write access to the same branches.

## Model server (`infer` + `jr`)

T3 Code supports OpenCode as one of its agents. OpenCode in turn can
point at any OpenAI-compatible endpoint, which is what Ollama / llama.cpp
expose on `infer`. The `jr` instance then reaches `infer` over the
bridge, with the egress ACL blocking everything else.

**Model**: `gemma4:12b` (11.9B, Q4_K_M, 8.0 GB on disk; capabilities
include tools and thinking). It's already pulled into the host's Ollama.
Ollama's default context is 4096 tokens, too small for an agent, so the
host sets `OLLAMA_CONTEXT_LENGTH=32768`. Measured with the model fully on
the GPU: about 11.4 GB of the 12.3 GB VRAM, with the 7680×2160 desktop
running. A game alongside won't fit, which is what the gamemode hook is
for. If gemma falls short on real tasks, gpt-oss-20b is the fallback.

**Status: `jr` uses the host's Ollama for now** (`hosts/rainbow/homelab.nix`):

- Ollama stays on `127.0.0.1:11434`. Nothing else on the host changes.
  Blitz's local cluster runs its own Ollama and doesn't use this one.
- `ollama-bridge.socket` listens only on `10.80.0.1:11434` (the bridge
  address) and forwards to Ollama through `systemd-socket-proxyd`.
- The host firewall admits only `jr`'s pinned address (`10.80.0.50`) to
  that port. `eng`, `sec` and `doc` can't reach it.
- While a game is running (gamemode stops `ollama.service`), `jr`'s
  requests fail until it's back.

OpenCode's config is baked into the `jr` image at
`/etc/opencode/opencode.json` (`OPENCODE_CONFIG`, set for `t3-serve` and
for login shells). It sets the provider, the model, `autoupdate: false`
and `share: "disabled"`. The OpenAI-compatible adapter ships inside the
package; I checked that it fetches nothing from npm at runtime, which is
why `jr` can run with no internet at all.

nixpkgs' `opencode` 2.2.5 doesn't build at our pin, because the expected
hash of its `node_modules` download no longer matches. The `jr` image
carries a one-line overlay that corrects the hash, scoped to that image.
Drop it once nixpkgs is fixed.

Moving Ollama into `infer` will need:

- GPU passthrough into the container (not a VM — single-GPU + games
  makes VM passthrough painful).
- The gamemode hook extended to stop/start the `infer` container the
  same way it currently gates `ollama.service`.
- A decision on whether host Ollama goes away entirely or stays for
  non-agent use (CLI, embeddings, etc.).

**Caveats**: local open models are less reliable at tool use and at
following long specs than the hosted frontier models. That's why `jr`
gets only the lowest-risk tasks. Grow its scope as it proves itself.
The minimum OpenCode version T3 needs is unverified; check it at install
time.

## Suggested order

Already done:

- Incus base (`hosts/common/incus.nix`): bridge, pool, profiles, `dev`
  project, host-input lockdown on the bridge, `incus-admin` group.
- `pkgs.t3code` on the host.
- Shared agent module and the `eng` / `sec` / `doc` / `jr` image outputs.
- Host Ollama + gamemode stop/start hook.
- Host k3s (still worth re-questioning whether it belongs on the gaming
  host — see `STATUS.md`).

Next:

1. **Clean up the first cut**: *done in Incus (2026-11-07)* — `arch`
   and the old images are gone; `dev` holds only `eng-vm` / `eng-app`.
   Left on the host: `~/projects/blitz-app.worktree-old` (the retired
   worktree, clean, branch `blitz-app` at `main`), removable with
   `git -C ~/projects/blitz worktree remove ../blitz-app.worktree-old`.
2. **`eng-app`**: *done (2026-11-07).* Lane clone at `/work`, main
   checkout read-only at `/lead`, paired, Claude Code logged in,
   `baseline` snapshot taken. Verified: `t3-serve` comes up on its own
   after boot and restart, host reaches `:3773`, git commit and
   `fetch origin` work inside, `/lead` refuses writes, and the host can
   fetch the lane branch.
3. **`sec`**: *running (2026-11-07).* `~/projects/blitz-hardening` on
   `lane/hardening` at `/work`, main checkout read-only at `/lead`.
   Verified the same checks as `eng-app`, plus reading another branch
   (`blitz-app`) through `/lead`. Left for me: pair, log in, snapshot
   `baseline`; update Blitz's lane D brief for the broader role.
4. **`jr`**: *running (2026-11-07).* `~/projects/blitz-jr` on `lane/jr`
   at `/work`, `/lead` read-only, pinned at `10.80.0.50`. Verified after
   the host switch: `gemma4:12b` answers through the proxy (32k context,
   fully on the GPU, ~17s cold); OpenCode tool calls work (a read-only
   Glob task came back right, with no writes); `jr` can't reach the
   internet by name or IP but DNS still resolves through the host;
   `eng-app` and `sec` can't reach the proxy and still have internet.
   Left for me: pair, snapshot `baseline`.
5. **Team wired** (2026-11-07): persistent block home volumes for all
   three (logins and pairings carried over), anti-spoofing on, down-only
   T3 links created over loopback forwarders, `/work` registered as a T3
   project everywhere, and a `sec` → `jr` link test passed. Needs my host
   switch for the link-direction table. Old instance snapshots
   (`baseline`) were lost with the rebuild; retake them.
6. **`doc`** for lane E. Maybe not needed: each role now updates its own
   docs.

Later:

7. `infer` (GPU container): move Ollama off the host, repoint `jr`'s
   baseURL, and extend the gamemode hook to pause `infer`.

## Runbook: launching a role instance

Same steps for every role. The example is `eng-app` for Blitz lane B.

### Build and import the image (host)

```bash
ROLE=eng
DISK=$(nix build --no-link --print-out-paths .#$ROLE-image-disk)
META=$(nix build --no-link --print-out-paths .#$ROLE-image-metadata)
# Re-importing under the same alias replaces the old image. Both file
# names carry a version suffix, so glob rather than hardcode.
incus image import "$META"/tarball/*.tar.xz "$DISK"/*.qcow2 \
  --alias $ROLE-vm --project dev
```

### Make the lane clone (host)

Each lane gets its own **clone**, not a `git worktree`. A worktree's
`.git` file points at the main repo's `.git/worktrees/…` by host path,
so git fails inside the VM. Mounting the main `.git` to fix that would
let the VM rewrite every branch, and plant hooks or config that run on
the host. A clone confines the VM to one repo it fully owns. The repo is
small, so a second `.git` costs a few MB.

```bash
cd ~/projects
# --no-hardlinks matters: a local clone otherwise hardlinks object files,
# and the VM (uid 1000, same as me) could then modify the main repo's
# objects through the shared inode.
git clone --no-hardlinks blitz blitz-app
git -C blitz-app switch -c lane/app origin/main
# Inside the VM, origin is my checkout mounted read-only at /lead.
git -C blitz-app remote set-url origin /lead
```

### Launch and mount the lane

```bash
incus project switch dev

# Persistent home: an Incus *block* volume (the guest formats it ext4 and
# mounts it at /home/agent). Not a filesystem volume: those reach a VM
# over virtiofs, where T3's SQLite (WAL mode) fails with "disk I/O error".
incus storage volume create default home-eng-app --type=block size=10GiB

# Create without starting, so every device is in place before first boot.
# (Disk devices can't be hot-added to a running VM: QEMU has no free PCI
# slot. On an existing instance, stop -> add -> start, and don't stop it
# mid-first-boot; that hung once and needed -f.) The agent profile sets
# security.secureboot=false, so the unsigned NixOS kernel boots cleanly.
incus init eng-vm eng-app --vm -p default -p agent
# Every instance: a pinned address (host rules key on it) and anti-spoofing
# so no other instance can claim it. New instances use .2-.99.
incus config device override eng-app eth0 \
  ipv4.address=10.80.0.126 security.ipv4_filtering=true
# The device must be named `home`: the guest finds it as ...incus_home.
incus config device add eng-app home disk pool=default source=home-eng-app
# One writer per branch: while it's mounted, this instance owns lane/app.
incus config device add eng-app work disk \
  source=/home/vcaaron/projects/blitz-app path=/work
# Every role: my main checkout, read-only, as the clone's origin. `git
# fetch origin` inside the VM keeps the lane current with main; sec also
# reads other lanes' branches through it.
incus config device add eng-app lead disk \
  source=/home/vcaaron/projects/blitz path=/lead readonly=true
# Every role: the repos Blitz depends on, read-only. Blitz references
# them as ../ACE from its repo root, and /work/.. and /lead/.. are both /,
# so mount at /ACE and /Polar. Only these two: other projects under
# ~/projects hold .env files that eng/sec (internet) shouldn't read. Polar
# itself carries .env.nuon, .env.ci.nuon and dev/tmp/ca.key; accepted
# 2026-11-07. Lane A would need Polar writable (it commits there); not
# while A is paused.
incus config device add eng-app ace disk \
  source=/home/vcaaron/projects/ACE path=/ACE readonly=true
incus config device add eng-app polar disk \
  source=/home/vcaaron/projects/Polar path=/Polar readonly=true
# sec only, optional: a specific branch under review, read-only.
# incus config device add sec review disk \
#   source=/home/vcaaron/projects/blitz-app path=/review readonly=true
incus start eng-app

# Register the lane as a T3 project so threads (including ones other
# agents start over a link) have somewhere to run.
incus exec eng-app -- su - agent -c 't3 project add /work --title blitz'
# Docs say ~/projects/ACE and ~/projects/Polar; the symlinks live on the
# home volume, so this is once per instance.
incus exec eng-app -- su - agent -c \
  'mkdir -p ~/projects && ln -sfn /ACE ~/projects/ACE && ln -sfn /Polar ~/projects/Polar'
```

A new instance or a new pinned address also needs the host side
(`hosts/rainbow/homelab.nix`): its address in any rule that should cover
it, and in the link table if it takes part in links.

### Bringing lane work back (host)

```bash
# Fetch only. Never run git *inside* a lane clone on the host (status,
# log, pull, push into it): its .git/config and hooks are writable by the
# VM, and things like core.fsmonitor or a receive hook would execute as me.
git -C ~/projects/blitz fetch ../blitz-app lane/app:lane/app
# then review / merge in my own checkout as usual.
```

### Pair

`t3-serve.service` is already running. No zellij pane is needed.

```bash
incus exec eng-app -- systemctl status t3-serve --no-pager
incus exec eng-app -- su - agent -c 't3 pair'
```

Run `t3 pair` myself, in my own terminal. Don't have an agent run it,
because the link it prints is a credential. `t3 serve` also writes a
pairing QR to the VM's journal on every start, so treat
`journalctl -u t3-serve` output as sensitive.

Back on the T3 client (Mac / web / phone):

1. Add an environment using the pairing link.
2. Sign in to the harness(es) inside the environment. The logins live
   inside this VM, not on the host.
3. Paste the lane's kickoff message as the first message of the thread.

### Snapshot and rollback

```bash
incus snapshot create eng-app baseline
# ...run a task...
incus snapshot restore eng-app baseline
```

An instance snapshot covers the **root disk only**: OS and tools. It
does **not** cover the home volume (harness logins, T3 state, links),
which is snapshotted on its own (`incus storage volume snapshot create
default home-eng-app <name>`), or `/work` and `/lead`, which are host
directories. Roll back code with git in the lane (`git reset --hard
origin/main` inside the VM, or discard the lane branch), not with
`snapshot restore`.

### Re-rolling the image

When a role's `configuration.nix` or `hosts/common/agent-vm.nix`
changes, rebuild and re-import under the same alias (above). Instances
don't update themselves; recreate them. **The home volume carries over**,
so harness logins, T3 pairing, projects and links all survive. Only the
root disk is replaced.

```bash
incus delete -f eng-app
# then the `incus init` ... `incus start` block from "Launch and mount the
# lane", skipping the `storage volume create`. Same IP, same devices.
```

Done this way for `jr` on 2026-11-07: settings, projects and
`eng-app`'s link to it all came through unchanged.

### Links between environments (team wiring)

Run on the host for each down-only link (`from` → `to`). The token is
minted in `to` with thread-only scopes, piped into `from`, and never
printed. `from` must list `to` in `homelab.agentVm.t3Peers` (that gives
the loopback port), and the host link table must allow the pair.

```bash
link() { # from to local-port
  TOK=$(incus exec $2 -- su - agent -c "t3 pair --ttl 2m --label link-from-$1 \
    --scope orchestration:read --scope orchestration:operate" | sed -n 's/^Token: //p')
  incus exec $1 --user 1000 --group 100 --cwd /home/agent \
    --env HOME=/home/agent --env PC="$TOK" -- bash -lc \
    "t3 environment link --pairing-code \"\$PC\" --access auto-accept-edits http://127.0.0.1:$3"
  unset TOK
}
link sec eng-app 47301
link sec jr 47302
link eng-app jr 47302
incus exec sec -- su - agent -c 't3 environment list'
```

Links expire after 30 days. Re-running `link` renews one. Revoke one in
the target's T3 under Settings → Connections, or `t3 environment unlink`
in the source.

### Detach when the lane's work is merged

```bash
incus stop eng-app
incus config device remove eng-app work
# after fetching lane/app into my checkout and merging:
rm -rf ~/projects/blitz-app
```

## Open questions / TODO

- **Auto-start the homelab on rainbow boot.** `t3-serve` inside each VM
  is now declarative. Still imperative: image import, `incus launch`,
  and `config device add` for mounts. Nothing restarts the instances
  after a reboot unless `boot.autostart` is set on them. Ideas held in
  reserve, not yet chosen:
  - An Incus *profile* per role/lane holding its disk devices, so
    `incus launch -p role-eng-app` attaches the mounts.
  - An idempotent systemd oneshot on rainbow (after `incus.service`) that
    imports missing images, launches missing instances, and sets
    `boot.autostart`.
- **Encrypt the T3 links.** They run over plain http through loopback
  forwarders (T3 refuses plain http otherwise). Tailscale in each VM would
  let T3 link over tailnet addresses natively, and the same work covers
  phone/laptop access.
- **Link renewal.** Links expire after 30 days (current: 2026-12-08), and
  renewing them is a manual `link` run. Could become a host timer, but
  that would make the host mint tokens on a schedule. Decide when it bites.
- NixOS vs Debian for `infer` (leaning Debian for GPU container
  ergonomics). The agent roles are NixOS.
- Secrets: `sops-nix` vs `agenix` for per-instance GitHub PATs.
- Tailscale now or deferred? LAN pairing is fine while I'm at the desk;
  Tailscale unlocks the phone/laptop case.
- Pinning strategy for `pkgs.t3code` given upstream's "very very early"
  warning. Probably a dedicated flake input tracking a known-good tag.
- **Writable Nix store for lanes that build Rust.** A read-only
  `/nix/store` bind mount works for review-only use, but lanes compiling
  the Blitz workspace need to add paths. Options: a per-VM overlay store
  (safer), or a writable shared store (simpler, but accepts
  lateral-movement risk inside the `dev` project).
- **`jr`'s DNS.** Its egress block covers forwarded traffic, but the
  host's dnsmasq still resolves names for it, which is a slow
  exfiltration channel. Options: an nftables input rule refusing DNS from
  `10.80.0.50` (it only needs the proxy, by IP), or per-instance dnsmasq
  config. Low priority while `jr` only gets low-risk tasks.
- **Model for `jr`**: `gemma4:12b` to start (gpt-oss-20b as fallback). Record
  what was tried and how it did on real forwarded tasks.

## References

- https://t3.codes
- https://github.com/pingdotgg/t3code
- https://github.com/pingdotgg/t3code/blob/main/docs/user/install.md
- https://github.com/pingdotgg/t3code/blob/main/docs/user/remote-access.md
- `hosts/common/incus.nix` — base infrastructure this plan builds on
- `hosts/common/agent-vm.nix` — shared agent VM image module
- `~/projects/blitz/docs/lanes/README.md` — the lane model the roles map onto
- `hosts/rainbow/STATUS.md` — gaming-perf doc; cross-references the
  GPU-contention / k3s baseline questions
