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
(~12 GiB VRAM); `jr` runs `omnicoder-9b` (~5.7 GB; on trial, see
"Model server"). The
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
   turns my goal into tasks and hands them to `eng`, `test` and `jr`
   over T3 links (see **Team** below). `eng` and `test` hand `jr` the
   low-risk pieces directly and check its output. Questions go up the
   chain, `jr` → whoever gave it the task, `eng`/`test` → `sec`. Only
   what `sec` can't settle comes to me.
2. **Gates that stay with me:** merging to `main`, anything applied to a
   cluster or the cloud, new attack surface (ports, egress, credentials),
   and changing what the product is for. An agent that reaches one stops
   and says so in its thread.
3. **Each role owns its lane's files, and its own docs.** It edits only
   its lane's paths. Updating the documentation its work makes untrue,
   manuals included, is the last required step of every task, in the
   same branch. There's no writer role (`doc` was dropped 2026-11-08). A
   change needed in another lane's files goes to that lane's agent as a
   task (via `sec`), not as an edit.
4. **Links point down only:** `sec` → `eng-app`, `sec` → `test`,
   `sec` → `jr`, `eng-app` → `jr`, `test` → `jr`. A driven agent acts
   with its own credentials and egress, so `jr` (no internet, no keys)
   never drives anyone. The host enforces the direction at the network
   as well as in T3.

| Role | Image | Does | Harness | Writes | Reads | Egress |
|---|---|---|---|---|---|---|
| **Lead** (me) | — (host) | Sets goals, answers questions, merges, deploys; ops until an `ops` instance exists | — | `main` checkout, cluster, cloud | everything | — |
| **Backend/systems engineer** | `eng` | Writes code: features, fixes, unit tests, infra sources | Claude Code, Codex | its lane clone at `/work` | my main checkout at `/lead`, `readonly=true` (the clone's origin) | frontier APIs, GitHub |
| **DevSecOps engineer** (my right hand) | `sec` | Owns the delivery process end to end: pipeline, hardening, threat model, config, process docs, findings, reviews, and tasks for other roles (see below) | Claude Code, Codex | its lane clone at `/work` | my main checkout at `/lead` (all lanes' branches, handoffs, requests); optionally a branch at `/review`; both `readonly=true` | frontier APIs, GitHub |
| **Test engineer** | `test` | Checks independently that the work works: integration and end-to-end suites, load tests, stack checks, release-candidate checks, and checking that the manuals' procedures still hold | Claude Code, Codex | its lane clone at `/work` | my main checkout at `/lead`, `readonly=true` (the clone's origin) | frontier APIs, GitHub; local cluster ingress later (TODO) |
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
- **`jr`'s model is `omnicoder-9b`** (Q4_K_M, ~5.7 GB, on trial against
  `gemma4:12b`; see "Model server"). OpenCode
  points at an Ollama OpenAI-compatible endpoint. Its config is baked into
  the image, limited to that one local model.
- **Reviews.** `sec` is the reviewer. A second opinion from `jr` is
  cheap and optional. It never replaces `sec`'s review.
- **`test` vs `eng` vs `sec`.** `eng` writes unit tests for its own
  code. `test` owns everything that checks the system from outside:
  integration, end-to-end and load suites, and their fixtures. `sec`
  owns the pipeline that runs them, and the threat model the security
  tests come from. `test` doesn't edit the pipeline, and `sec` doesn't
  write the suites.
- **Ops.** Deploying is mine for now (rule 2's gate), with `eng`
  writing the `infra/` sources. When cloud work resumes, an `ops`
  instance can be launched from the `eng` image.

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
- **Tasks for `eng`, `test` and `jr`**, started directly in their environments
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
               me (host T3: watches every session, owns the gates)
                │ goal
                ▼
               sec            Claude Code; coordinates, reviews, threat model
        ┌───────┼────────┐
        ▼       │        ▼
     eng-app    │      test   Claude Code; implementation / verification
        │       ▼        │
        └────▶  jr  ◀────┘    OpenCode + omnicoder-9b; low-risk pieces
```

`test` was launched 2026-11-08; see "Suggested order" for its status.

**Mechanism.** Each arrow is a `t3 environment link`, created in the
upper VM. Agents in that VM's T3 sessions get T3's tools for the linked
environment: list projects, start a thread with a chosen provider and
model, message it, read its replies. A busy thread gets a message as its
next turn. Each link:

- has **only `orchestration:read` and `orchestration:operate`** scopes,
  so threads only. No terminal, filesystem, settings, provider or token
  scopes; T3's default pairing grants all of those.
- runs at the access I picked for its target, never full access. A
  driven agent edits its own lane clone without asking anyone.
  `eng-app` and `test` are linked at **`auto`**; `jr` at
  **`auto-accept-edits`** (it hasn't earned more), from every source.
- goes over a **loopback forwarder** in the upper VM
  (`http://127.0.0.1:4730x`, from `homelab.agentVm.t3Peers`). T3 only
  links over plain http to loopback or Tailscale, so the link token
  crosses the host-internal bridge unencrypted. That's acceptable on a
  bridge with anti-spoofing; Tailscale is the upgrade.
- **expires after 30 days** (current ones: 2026-12-08). Renew with the
  link runbook below.

**Picking models.** T3 projects have no default model, so whoever starts
a thread names one. `eng-app`/`sec`/`test`: provider `claudeAgent`, e.g.
`claude-sonnet-5-5` or `claude-opus-5-5`. `jr`: provider `opencode`,
model `ollama/omnicoder-9b` (the only one it offers).

**Verified 2026-11-07:** `sec`'s Claude found `jr` over its link, started
a thread on gemma, waited, and relayed `PONG`, in about 35s, with no
files changed.

**Kicking off a goal** (paste into a new `sec` thread, with
`claudeAgent`):

```
You coordinate an agent team for the lead (me) who is watching and primarily responsible for goal setting, maintaining alignment with project vision, and architecutre.

Your linked environments: eng-app (backend/systems engineer, Claude Code,
lane clone /work on lane/app), test (test engineer, Claude Code, lane
clone /work on lane/test; once launched) and jr (junior engineer,
OpenCode with ollama/omnicoder-9b, lane clone /work on lane/jr,
lowest-risk work only). Read /lead/AGENTS.md and
/lead/docs/lanes/README.md first. Team rules on top of those: links
point down (you -> eng-app/test/jr, eng-app/test -> jr); questions go
up; each agent edits only its lane, and updating the docs (manuals
included) its work makes untrue is the last step of every task; stop at
the gates (merge, cluster/cloud apply, new ports/egress/credentials,
product direction). 

The project's AGENTS.md and other docs specify rules that every agent should adhere to. If one is not present or unclear, ask me and I will clarify.

```

### Mapping onto Blitz

Blitz (`~/projects/blitz`) already runs this shape as swimlanes
(`docs/lanes/README.md`). Each lane has one checkout and one branch, and
owns explicit paths. **Planned 2026-11-08:** consolidate Blitz's lanes
A–E into four, split by function rather than by part of the product.
The draft is in Blitz at `docs/lanes/PROPOSAL-2026-11-08-lanes.md`
(uncommitted); `sec` lands it after its current goal.

| Blitz lane (planned) | Was | Role / instance | Lane clone mounted at `/work` |
|---|---|---|---|
| Lead | Lead | me, on the host | `~/projects/blitz` (main) |
| Ops | A (paused) | me for now; `ops` from the `eng` image later | `../blitz-cloud` when it exists |
| Implementation | B + C | `eng` → `eng-app` | `../blitz-app` |
| DevSecOps | D | `sec` | `../blitz-hardening` (+ `~/projects/blitz` at `/lead`, read-only) |
| Test | new | `test` | `../blitz-test` |
| (the manual) | E (retired) | every role, as the last step of each task | — |
| (none) | — | `jr` | `../blitz-jr`, on `lane/jr` |

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
- `hosts/rainbow/agents/{eng,sec,test,jr}/configuration.nix` — one per
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
  - `eng`, `sec`, `test`: still open. The target allowlist is
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
- **Permission modes.** Keep Full access off. Engineer and test threads
  run Supervised or auto. Review threads run Supervised. `jr`
  runs Supervised until it has earned more.
- **Pin T3.** Under Nix, T3 is updated through Nix, not `t3 update`. The
  version is whatever `flake.lock` pins, and images only change when
  rebuilt.
- **T3 Connect.** T3 Code's docs don't tell you to avoid Connect — they
  describe it as a NAT-traversal relay with a 3-machine cap on the free
  tier. We're avoiding it on principle: no third-party relay in the
  loop. `t3 serve --lan` (or `--tailscale-serve` once Tailscale is in)
  is enough.

## Housekeeping (standing order)

**Disk is the scarcest thing in this homelab.** The Incus pool is a
100 GiB loop file shared by every VM, on a host disk that's 89% full. A
full pool takes every VM down at once. On 2026-11-08 it was at 92 GiB:
8 superseded images plus eng-app's 26 GiB Nix store. Deleting those
and trimming brought it to 35 GiB.

**The order, for every agent (in a VM or on the host) and for me:**
remove an image, container, volume or build output **as soon as it's
stopped or superseded**. Don't keep anything "just in case". The source
is in git and Nix can rebuild it.

What runs on its own (in the images, `hosts/common/agent-vm.nix`):

- **Nix:** garbage collection during a build whenever free space drops
  below 3 GiB (until 10 GiB is free), plus a weekly `nix-gc`.
- **Pool-pressure GC.** `min-free` only sees the VM's own thin disk, which
  looks free while the pool fills. So when the host's pool feed says
  `warn` (80%+), each VM collects its Nix garbage and trims, at most every
  30 minutes, and logs what it freed (`journalctl -t homelab`).
- **Online discard on `/` and the home volume** (`discard` in their
  mount options, from 2026-11-10 images). ext4 discards blocks as files
  are deleted, so the pool shrinks at once. This was added because
  builds free 5-8 GiB an hour, which the hourly trim couldn't keep up
  with. On 2026-11-10 the pool sat at 83.7 GiB, sec and test stopped
  work, and a manual trim of all four VMs recovered 8.5 GiB. A VM gets
  this at its next re-roll; check with
  `incus exec <vm> -- findmnt -no OPTIONS /`.
- **`fstrim` hourly, as a backstop.** Space freed inside a VM only returns to the pool
  once the guest discards it, and online discard can skip small extents. `incus exec <vm> -- fstrim -av` does it
  now.
- **Podman (`test`):** `agent-podman-prune` hourly removes stopped
  containers, unused volumes and dangling images, and daily (03:00)
  every image no container uses. Container storage is on the root disk,
  so a re-roll wipes it too.

What stays manual:

- **After every image import, delete the image it superseded.** The
  import runbook below does this. Re-importing under an alias leaves the
  old image untagged and still taking space.
- **Snapshots:** delete a `before-<task>` snapshot once the task is
  merged or dropped. Keep one `baseline` per instance.
- **Detached lanes:** remove the lane clone and the instance once the
  lane is merged (see "Detach").
- **Agents in the VMs:** remove containers they start (testcontainers
  does this on drop) and don't leave `podman build` images or extra
  cargo target dirs behind. This is in the Blitz process docs (`sec`
  owns them).
- **Check** with `incus storage info default | grep "space used"` and
  `incus info <vm>` (root and home usage).
- **Agents see the pool too.** Inside a VM, `df` shows only that VM's
  thin disk, which can look free while the pool is full. Every 2 minutes
  the host (`homelab-pool-status` in `homelab.nix`) publishes the pool's
  usage into each running VM's config (`user.homelab.pool`). The VM
  copies it to `/run/homelab/pool` and logs a warning from 80% (critical
  from 90%). Agents run `homelab-pool`. This uses the Incus guest API, so
  there's no mount and nothing on the network.
- **The pool is charged for blocks a VM hasn't trimmed.** After big
  deletes, run `incus exec <vm> -- fstrim -av` rather than waiting for the
  daily timer. On 2026-11-08 eng-app (an image older than the timer)
  had the pool at 76 GiB; trimming it brought the pool back to 53 GiB.

**GC roots: what a collection must not take.** A GC removes anything
unrooted. In a lane VM that includes the Blitz `ci` shell (~5 GiB to
fetch again) and the ACE flake input. ACE can't be refetched in a VM:
`flake.nix` pins it over SSH to a server the VMs can't reach. Each VM
has two roots under `~/.local/state/nix/profiles/` (the images set
`keep-outputs`/`keep-derivations`, so these also keep the inputs behind
them):

```bash
# inside the VM, as agent. path: because libgit2 can't read the virtiofs
# /work (same bug as /ACE).
cd /work
nix develop --profile ~/.local/state/nix/profiles/blitz-ci "path:/work#ci" --command true
# ACE at the rev flake.nix pins, from the local clone; same narHash, so
# later evaluations find it in the store and never try SSH.
R=$(grep -o 'ACE.git?rev=[0-9a-f]*' flake.nix | cut -d= -f2)
P=$(nix flake archive --json path:/work \
      --override-input ace "git+file:///home/agent/projects/ACE?rev=$R" | jq -r .inputs.ace.path)
nix-store --realise "$P" --add-root ~/.local/state/nix/profiles/ace-src
```

**A re-roll wipes the store.** The Nix store is on the root disk, which a
re-roll replaces; the roots above live on the home volume and are left
pointing at nothing. The lane VMs (eng, sec, test) import
`agents/common/blitz-lane.nix`, which installs this as `blitz-roots` and
runs it at every boot (`systemd.services.blitz-roots`, as `agent`). So a
re-roll costs one ~5 GiB shell download per VM, then heals itself.
Run `blitz-roots` by hand when the lane bumps the `ci` shell or ACE's pin.
On 2026-11-08 the module was added after the last re-roll, so the VMs
have a hand-pushed copy at `~/.local/bin/blitz-roots` until their next
re-roll (delete it then).

**Agents don't run store-wide GC.** It needs root, and Codex's approval
reviewer rightly declines it. The pool-pressure GC above is the
mechanism.

Still open: share one Nix store or binary cache across the VMs, so each
one stops downloading and building the same closures.

## Networking and client access

T3 Code's reachability modes are:

- `t3 serve --lan` — accepts LAN and tailnet connections; a one-time
  pairing link is all that gates other devices on the same network from
  joining. Each `t3 pair` invocation yields a fresh one-time link.
- `t3 serve --tailscale-serve` — Tailscale-fronted HTTPS. Preferred
  remote option once Tailscale is in the Nix config.

### Phone access over Tailscale (2026-11-08)

Rainbow is on the tailnet (`tail0c011d.ts.net`, `services.tailscale` in
`system.nix`). The lane VMs (eng, sec, test) have
`homelab.agentVm.tailscale = true`:

- `tailscaled` keeps its node state on the home volume
  (`~/.local/state/tailscale`, root-only, bind-mounted to
  `/var/lib/tailscale`), so a re-roll keeps the device and its login.
- `--operator=agent` lets T3 (running as `agent`) configure
  `tailscale serve` itself.
- `t3-serve` runs with `--lan --tailscale-serve`. Desktop pairings over
  the bridge keep working, and the phone uses
  `https://<name>.tail0c011d.ts.net`. If Tailscale isn't logged in, T3
  logs "Failed to configure Tailscale Serve" and carries on with `--lan`.

Tailnet prerequisites (admin console, mine): MagicDNS and **HTTPS
certificates** on, and an ACL that tags the VMs `tag:agent`, lets my
devices reach `tag:agent` on 443, and gives the agents nothing else.

**Join a VM (once per home volume).** No auth key: I approve each
device in the browser, so no credential passes through anyone.

```bash
# --operator=agent is required here too: `up` resets every pref it isn't
# given, and T3 then gets "permission-denied" from `tailscale serve`.
incus exec <inst> -- tailscale up --advertise-tags=tag:agent --hostname=<inst> --operator=agent
# prints https://login.tailscale.com/a/...; open it, approve
incus exec <inst> -- systemctl restart t3-serve   # now Serve gets configured
incus exec <inst> -- tailscale serve status       # shows https://<inst>.<tailnet>.ts.net
```

**Pair the phone:** `incus exec <inst> -- su - agent -c 't3 pair'` in my
own terminal, then in the T3 app add the environment at
`https://<inst>.tail0c011d.ts.net` with that code. Start with `sec`.

**The host's own T3 (the sysadmin thread) is on port 8443:**
`https://rainbow.tail0c011d.ts.net:8443`, set up 2026-11-09 with
`tailscale serve --bg --https=8443 http://127.0.0.1:3773`. That port is
the desktop app's server. The serve config persists in tailscaled's
state.

Not 443: k3s's bundled Traefik (ServiceLB) holds 443 on every
interface, including `tailscale0`, and answers before Tailscale Serve
does, presenting `TRAEFIK DEFAULT CERT`. The old `:443` serve entry
is dead; remove it with `tailscale serve --https=443 off`.

Pair the phone with the host the same way as with a VM: run `t3 pair`
in my own terminal on rainbow. The ACL must let my devices reach
`rainbow:8443`.

Later: move the agents' links onto the tailnet names and retire the
loopback forwarders (TODO "Encrypt the T3 links").

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

**Model (on trial since 2026-11-09)**: `omnicoder-9b`, which is
OmniCoder-9B: Tesslate's fine-tune of Qwen3.5-9B on coding-agent
traces (tool calls, read-edit-test loops), Apache 2.0, Q4_K_M, 5.7 GB.
It's on trial because jr's work is mostly driving OpenCode's tools,
which gemma was never trained for.
- **Memory:** fully on the GPU at 6.4 GB with 32k context. With the
  desktop running, the card uses 10.3 of its 12.3 GB.
- **Smoke tests:** `PONG` through the proxy, and a read-only tool task
  (read `flake.nix`, name its dev shells) came back right in 7 seconds.
- **Thinking is off** (`options.reasoningEffort = "none"` in jr's
  OpenCode config, sent as `reasoning_effort`). With thinking on, the
  official build often put its final answer inside the reasoning and
  returned no text, so OpenCode and T3 showed an empty reply. It also
  thought for ~2k tokens per turn, so tool tasks took 40-140 s; with
  thinking off they take 2-5 s once warm. The community re-upload
  didn't show this, probably because of a different chat template.
- **Swapping weights under the same name:** `opencode run` attaches
  to a background `opencode serve --service`, which keeps the config it
  started with. After changing the model or its options, re-roll jr or
  kill that daemon, or a test is still running the old setup. When
  killing it from a `bash -c`, use the pattern
  `[o]pencode-wrapped serve --service`, so `pkill` doesn't match the
  shell's own command line.
- **The verdict comes from real work:** sec routes two or three
  jr-sized pieces to it and reports how many finished without help,
  plus any malformed tool calls or lost threads. Record the result
  under "Open questions".

**The previous model**: `gemma4:12b` (11.9B, Q4_K_M, 8.0 GB on disk;
tools and thinking). It used about 11.4 GB of VRAM at 32k context
with the desktop running, too tight for a game alongside, which is
what the gamemode hook is for. It has been removed from the host. To
compare the two, pull it again (`ollama pull gemma4:12b`) and change
`model` in `agents/jr/configuration.nix`. The fallback beyond both is
gpt-oss-20b.

Ollama's default context is 4096 tokens, too small for an agent, so the
host sets `OLLAMA_CONTEXT_LENGTH=32768` for every model.

**Getting a model from Hugging Face.** Ollama pulls GGUF files from
Hugging Face directly, with the quantization as the tag:

```bash
ollama pull hf.co/Tesslate/OmniCoder-9B-GGUF:Q4_K_M
# jr's config names `omnicoder-9b`, so point that name at it (no copy:
# the blobs are shared), then drop whatever it replaced.
ollama cp hf.co/Tesslate/OmniCoder-9B-GGUF:Q4_K_M omnicoder-9b
ollama rm carstenuhlig/omnicoder-9b
```

Prefer the model's own publisher over re-uploads. `omnicoder-9b` is
now an alias of Tesslate's own build. The first trial used a community
re-upload (`carstenuhlig/omnicoder-9b`), since removed. Hugging Face also has
"abliterated"/"heretic" variants with the safety tuning stripped; those
don't belong on an agent. A model name in jr's config must match
`ollama list` exactly, or every request 404s: OpenCode doesn't add
`:latest` or the publisher prefix.

**Status: `jr` uses the host's Ollama for now** (`hosts/rainbow/homelab.nix`):

- Ollama stays on `127.0.0.1:11434`. Nothing else on the host changes.
  Blitz's local cluster runs its own Ollama and doesn't use this one.
- `ollama-bridge.socket` listens only on `10.80.0.1:11434` (the bridge
  address) and forwards to Ollama through `systemd-socket-proxyd`.
- The host firewall admits only `jr`'s pinned address (`10.80.0.50`) to
  that port. `eng`, `sec` and `test` can't reach it.
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
- Shared agent module and the `eng` / `sec` / `test` / `jr` image outputs.
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
6. **`test`**: *running (2026-11-08).* Replaces `doc` (dropped: each
   role updates its own docs, manuals included). `~/projects/blitz-test`
   on `lane/test` at `/work`, `/lead` read-only, pinned at `10.80.0.60`
   with `ipv4_filtering`, `home-test` block volume, `/work` registered
   as a T3 project. `sec` re-rolled for its `47303` forwarder (home
   volume snapshot `before-reroll-2026-11-08` taken first). Links
   `sec` → `test` (auto) and `test` → `jr` (auto-accept-edits) created.
   Verified: `/lead` refuses writes, `git fetch origin` works, and on
   T3's port `test` reaches only `jr`, while only `sec` reaches `test`.
   Left for me: pair, log Claude Code in, snapshot `baseline`, and the
   kickoff once the test lane's brief exists in Blitz.
7. **Where `test` runs things against a live stack.** Two separate
   questions, both new attack surface in `homelab.nix`, decided when
   needed:
   - Stack checks (`signin-check.py`, `api-check.py`) against my local
     cluster: HTTP(S) to its ingress only, no Kubernetes API or
     kubeconfig; deploys stay mine.
   - Load tests: Blitz's load-testing plan
     (`docs/architecture/load-testing-plan.md`) says runs happen on a
     **disposable cluster, never the lead's**. So `test` needs somewhere
     disposable to point at (another Incus instance running k3s, or a
     cloud sandbox), not a route to mine.

Later:

8. `infer` (GPU container): move Ollama off the host, repoint `jr`'s
   baseURL, and extend the gamemode hook to pause `infer`.

## Runbook: launching a role instance

Same steps for every role. The example is `eng-app` for Blitz lane B.

### Build and import the image (host)

```bash
ROLE=eng
DISK=$(nix build --no-link --print-out-paths .#$ROLE-image-disk)
META=$(nix build --no-link --print-out-paths .#$ROLE-image-metadata)
# Re-importing under the same alias moves the alias but keeps the old
# image, untagged, taking pool space. Delete it straight away
# ("Housekeeping"). Both file names carry a version suffix, so glob.
OLD=$(incus image list --project dev -f csv -c lf | awk -F, -v a=$ROLE-vm '$1==a{print $2}')
incus image import "$META"/tarball/*.tar.xz "$DISK"/*.qcow2 \
  --alias $ROLE-vm --project dev
[ -n "$OLD" ] && incus image delete --project dev "$OLD"
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
# `balloon`: free-page reporting, so memory the guest frees goes back to
# the host (see "Housekeeping").
incus init eng-vm eng-app --vm -p default -p agent -p balloon
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
# agents start over a link) have somewhere to run. `t3 project add`
# refuses while a server owns the T3 home (ServerAlreadyRunningError),
# and t3-serve starts at boot, so stop it around the add.
incus exec eng-app -- systemctl stop t3-serve
incus exec eng-app -- su - agent -c 't3 project add /work --title blitz'
incus exec eng-app -- systemctl start t3-serve
# Docs say ~/projects/ACE and ~/projects/Polar; these live on the home
# volume, so this is once per instance. ACE must be a real clone, not a
# symlink to /ACE: Nix's libgit2 fails on the read-only virtiofs mount
# ("object not found", 2026-11-08), which breaks `nix develop` there and
# so Blitz's builder-cargo.sh. Update it with
# `git -C ~/projects/ACE pull --ff-only` (origin is /ACE). Polar stays a
# symlink until something needs its flake.
incus exec eng-app -- su - agent -c \
  'mkdir -p ~/projects && git clone -q /ACE ~/projects/ACE && ln -sfn /Polar ~/projects/Polar'
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

### One ACE clone per VM (rule, 2026-11-09)

Each lane VM has exactly one ACE repository, `~/projects/ACE`: a
clone of `/ACE`, which is the host's `~/projects/ACE`.

- **Do:** work on branches in that clone.
- **Don't:** make second clones, `git worktree`s, or a `cp -r` of it.

Why:

- `blitz-roots` re-seeds the Blitz `ci` shell's ACE input from that
  clone at boot, so it has to exist and stay a real clone.
- Every extra copy costs space on the 10 GiB home volume.
- With more than one copy, nobody can tell which tree is current.
  eng-app grew three: `ACE`, an `ACE-deploy` cloned from it, and an
  `ACE-on-main` worktree of that.

Agents can't push: `/ACE` is a read-only mount. Hand-offs are memos
naming a branch and SHA in `~/projects/ACE`. Update the clone with
`git -C ~/projects/ACE fetch origin` and fast-forward from there.

### Bringing ACE work back (host)

The VM's home is a block volume, so its git repositories aren't on the
host's filesystem. Move commits as a bundle. Never run git inside the
VM's repository from the host: same reason as for lane clones.

```bash
exec </dev/null
# 1. In the VM: bundle the named branches. A bundle needs ref names, not
#    bare SHAs ("empty bundle"); make a temporary branch if a memo
#    names only a SHA.
incus exec eng-app --project dev --user 1000 --env HOME=/home/agent -- \
  bash -lc 'cd ~/projects/ACE && git bundle create /tmp/ace.bundle deploy/port-fork deploy/on-main'
incus file pull eng-app/tmp/ace.bundle /tmp/ace.bundle --project dev
incus exec eng-app --project dev -- rm -f /tmp/ace.bundle

# 2. On the host: verify, fetch into a side namespace, and check that
#    every move is a fast-forward before touching a branch.
cd ~/projects/ACE
git bundle verify /tmp/ace.bundle
git fetch /tmp/ace.bundle 'refs/heads/*:refs/eng/*'
git merge-base --is-ancestor deploy/on-main refs/eng/deploy/on-main && echo ff
git update-ref refs/heads/deploy/on-main refs/eng/deploy/on-main <old-sha>   # old value guards the move
for r in $(git for-each-ref refs/eng --format='%(refname)'); do git update-ref -d $r; done
rm /tmp/ace.bundle

# 3. Back in the VM, the clone catches up from origin (/ACE).
incus exec eng-app --project dev --user 1000 --env HOME=/home/agent -- \
  bash -lc 'git -C ~/projects/ACE fetch origin'
```

Pushing to SEI's server is the lead's. Watch the names: the local
`port/public-polar/blitz-deploy` (slash) tracks the server's
`port/public-polar-blitz-deploy` (dash), so give the push an explicit
refspec: `git push origin port/public-polar/blitz-deploy:port/public-polar-blitz-deploy`.

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

### Day to day: `vm` in nushell

`hosts/rainbow/programs/nushell/homelab.nu` (autoloaded on rainbow) wraps
the commands below. With no names, each acts on every instance in `dev`.

- `vm ls`: state, address and newest backup of each VM, plus pool usage.
- `vm up [vm...]`: start them.
- `vm down [vm...] [-t 120]`: clean shutdown. A VM that doesn't stop in
  time is reported, never forced. Check no agent is mid-turn first.
- `vm backup [vm...] [-k 2]`: export each home volume (see below).
- `vm watch [-r 3sec]`: live dashboard (nushell's built-in `tui`). Pool
  bar, host memory, GPU, and per VM: CPU %, memory, root and home use,
  disk writes, backup age. Data is one `incus query /1.0/metrics` per
  refresh (guest-side, via the Incus agent; stopped VMs show none). Keys
  act on the highlighted VM: `u` up, `d` down (asks first), `b` backup,
  `s`/Enter shell. In zellij they open floating panes, so the dashboard
  keeps running. The `rainbow` zellij layout (`zr`) runs it in the
  homelab tab and next to btop in the monitor tab.

### Backups

Snapshots live in the pool, so they don't survive losing it, and they
grow the pool as a home changes. `vm backup` exports each **home volume**
(logins, T3 state and links, `~/projects`) to
`~/backups/homelab/<vm>/home-<vm>-<stamp>.tar.gz` on the host disk:
`incus storage volume export --volume-only`. The root disk comes from the
image, so it isn't backed up. It refuses running VMs (`vm down` first),
so ext4 is clean. Writes go to `.part` and are renamed on success; only
then are older files pruned to the newest `--keep` (default 2). jr's home
took 13 s and 26 MB (2026-11-10).

**These files hold harness login tokens.** `~/backups/homelab` is 0700;
don't copy them off the host or into the store.

Restore (not yet drilled):

```bash
vm down jr
incus storage volume import --project dev default \
  ~/backups/homelab/jr/home-jr-<stamp>.tar.gz home-jr-restored
incus config device set --project dev jr home source=home-jr-restored
vm up jr   # check logins, `t3 environment list`, ~/projects
incus storage volume delete --project dev default home-jr   # once it checks out
```

### Re-rolling the image

When a role's `configuration.nix` or `hosts/common/agent-vm.nix`
changes, rebuild and re-import under the same alias (above). Instances
don't update themselves; recreate them. **The home volume carries over**,
so harness logins, T3 pairing, projects and links all survive. Only the
root disk is replaced.

Lessons from 2026-11-08:

- **Scripted, close stdin** (`exec </dev/null` or `incus … </dev/null`).
  Run without a terminal, `incus storage volume snapshot create` hung
  for 10+ minutes with no operation on the server; with stdin closed it
  takes milliseconds.
- **Snapshot the home volume first**, verify the re-roll (links, logins,
  `~/projects/ACE`, `homelab-pool`), then prune to one snapshot per
  volume. Pick the one to keep by creation date
  (`incus storage volume snapshot list … -f csv` column 2), not by
  sorting names: mixed name formats sort wrongly under the locale, and
  that deleted the newest one once.

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
link() { # from to local-port access
  TOK=$(incus exec $2 -- su - agent -c "t3 pair --ttl 2m --label link-from-$1 \
    --scope orchestration:read --scope orchestration:operate" | sed -n 's/^Token: //p')
  [ -n "$TOK" ] || { echo "no token from $2"; return 1; }
  incus exec $1 --user 1000 --group 100 --cwd /home/agent \
    --env HOME=/home/agent --env PC="$TOK" -- bash -lc \
    "t3 environment link --pairing-code \"\$PC\" --access $4 http://127.0.0.1:$3"
  unset TOK
}
link sec eng-app 47301 auto
link sec test 47303 auto
link sec jr 47302 auto-accept-edits
link eng-app jr 47302 auto-accept-edits
link test jr 47302 auto-accept-edits
incus exec sec -- su - agent -c 't3 environment list'
```

Loopback ports are per target: `eng-app` 47301, `jr` 47302, `test`
47303. On 2026-11-08 every link had disappeared at once (cause unknown);
I relinked `sec` → `eng-app` and `sec` → `jr` only. Later that day,
right after `sec` was re-rolled, its `jr` link was gone again while its
`eng` link survived (not checked just before the re-roll, so it may
have gone earlier); it was relinked along with `sec` → `test` and
`test` → `jr`. `eng-app` → `jr` is still unlinked. Check
`t3 environment list` in each source after any re-roll.

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

- **Pause the agent VMs while a game runs.** gamemode's start/end hooks
  (`hosts/common/gaming.nix`) already stop and start `ollama.service`.
  The same hooks could `incus pause` / `incus start` the running agent
  instances, freeing their CPU (and, with the balloon, much of their
  RAM) for the game. Needs a polkit-free way for the gaming user to run
  it (`vcaaron` is in `incus-admin`, so plain `incus` works) and a list
  of which instances were running, so `end` resumes only those.
  Deferred 2026-11-08: Ollama agents aren't in use right now.
- **`jr` is benched** (2026-11-08): stopped, `boot.autostart=false`, its
  image no longer rebuilt. Its links from `sec` and `test` stay but
  report unreachable. Bring it back with `incus start jr` and
  `boot.autostart` unset.
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
  Tailscale unlocks the phone/laptop case. **Next up (2026-11-08):**
  driving the team from the T3 mobile app.
- **Chatops over Signal:** plan in `CHATOPS.md` (a `relay` instance
  bridging a "rainbow-ops" Signal group to `sec`). Not built.
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
- **Model for `jr`**: started on `gemma4:12b`; `omnicoder-9b` on trial
  since 2026-11-09 (gpt-oss-20b as fallback). Record what was tried and
  how it did on real forwarded tasks:
  - *omnicoder-9b, 2026-11-09:* smoke tests pass (PONG; a read-only
    tool task, 2-5 s warm) on Tesslate's official Q4_K_M, with thinking
    off (with it on, replies came back empty). Waiting on sec's report from real tasks.

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
