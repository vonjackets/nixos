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
on. Tasks come from me, questions go to me, and I merge. There is no
architect agent; that was the first cut's `arch` role, and it's gone.

Three rules apply to every role:

1. **Tasks come from the lead.** An agent does the task it was given and
   stops. It doesn't pick up work on its own, and it doesn't take work
   from another agent.
2. **Questions go to the lead.** If an agent is blocked or unsure, it
   asks me in its T3 thread and waits. It doesn't route around a refusal
   or guess at intent. Agents don't talk to each other directly.
3. **Changes outside a role's lane are requests, not edits.** A role that
   needs a change in another lane's files writes a request on its own
   branch; I relay it. (This is Blitz's `docs/lanes/README.md` rule 2,
   and it's the same here.)
4. **Only I dispatch.** `sec` can *propose* tasks for other roles, but a
   proposal is not a task until I approve it and paste it into the target
   role's thread. No agent links to or messages another agent's
   environment (`t3 environment` stays unused for now).

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
  points at an Ollama OpenAI-compatible endpoint. The provider config is
  per-user state inside the VM for now, not baked into the image.
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
- **Proposed tasks** for other roles (`eng`, `doc`, `jr`), written in
  the project's request/kickoff format so I can approve one and paste it
  as-is. It proposes and I dispatch (rule 4). If a proposal needs a
  decision from me, it says so and waits.

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
dispatch to other agents, can't merge, and can't apply to a cluster.
Those are mine.

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
- Host firewall on `incusbr0`: only UDP 53/67, TCP 53 (DHCP + DNS)
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
- **Egress allowlist.** Today `hosts/common/incus.nix` only opens DHCP
  and DNS on the bridge, and everything else is blocked. When the
  instances are actually deployed, extend this to a per-role allowlist
  (Incus network ACLs or nftables rules on the bridge):
  - `eng`, `sec`, `doc`: `api.anthropic.com`, `api.openai.com`,
    `api.github.com`, `objects.githubusercontent.com`
  - `jr`: only `infer`'s bridge address and port
  - `infer`: no egress (pull models through the host, then copy them in)
  The exact Incus ACL flags vary by version, so check them against the
  Incus docs before relying on them.
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
That leaves about 4 GB of the 4070 for KV cache and runtime, so **don't
run it at its 256k maximum context**. Cap `num_ctx` (start around 32k)
and raise it while watching `nvidia-smi`. If it falls short on real
tasks, gpt-oss-20b is the fallback that still fits.

**Status**: Ollama still runs on the **host** today (`services.ollama`
with `ollama-cuda`, `CUDA_VISIBLE_DEVICES=0`), not inside `infer`. The
host's `gamemode` custom hook already stops `ollama.service` on game
start and restarts it on game end (`hosts/common/gaming.nix`), so the
GPU-contention problem is managed for now. Until `infer` exists, `jr`
could point at the host's Ollama on `10.80.0.1` as a stopgap. That needs
a host firewall rule on `incusbr0`, which is an attack-surface decision
to call out in its own commit. Moving Ollama into `infer` will need:

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
  project, egress lockdown, `incus-admin` group.
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
4. **`doc`** for lane E.

Later:

5. `infer` (GPU container) and `jr`. Pick the model, point OpenCode at
   `infer`, restrict `jr`'s egress to `infer` only, and extend the
   gamemode hook to pause `infer`.

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

# The agent profile sets security.secureboot=false, so the unsigned
# NixOS kernel boots cleanly.
incus launch eng-vm eng-app --vm -p default -p agent

# Disk devices can't be hot-added to a running VM (QEMU has no free PCI
# slot for virtiofs), so stop -> add -> start. Wait ~30s after a first
# boot before stopping; a stop issued mid-first-boot hung and needed -f.
incus stop eng-app
# One writer per branch: while it's mounted, this instance owns lane/app.
incus config device add eng-app work disk \
  source=/home/vcaaron/projects/blitz-app path=/work
# Every role: my main checkout, read-only, as the clone's origin. `git
# fetch origin` inside the VM keeps the lane current with main; sec also
# reads other lanes' branches through it.
incus config device add eng-app lead disk \
  source=/home/vcaaron/projects/blitz path=/lead readonly=true
# sec only, optional: a specific branch under review, read-only.
# incus config device add sec review disk \
#   source=/home/vcaaron/projects/blitz-app path=/review readonly=true
incus start eng-app
```

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

A snapshot covers the **VM's disk only**: tools, harness logins, T3
state. It does **not** cover `/work` or `/lead`, which are host
directories. Roll back code with git in the lane (`git reset --hard
origin/main` inside the VM, or discard the lane branch), not with
`snapshot restore`.

### Re-rolling the image

When a role's `configuration.nix` or `hosts/common/agent-vm.nix`
changes, rebuild and re-import under the same alias (above). Existing
instances don't update themselves. Either launch fresh ones from the
new alias, or replace the old one:

```bash
incus delete -f eng-app && incus launch eng-vm eng-app --vm -p default -p agent
# then re-add the disk devices. Harness logins and T3 pairing are lost
# with the instance's disk.
```

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
- **Re-rolls lose state.** Replacing an instance loses harness logins and
  T3 pairing. Consider a per-instance Incus storage volume mounted at
  `/home/agent` so a re-roll keeps them.
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
