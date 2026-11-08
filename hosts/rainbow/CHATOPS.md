# rainbow chatops: Signal ↔ agent team (plan, not built)

Drafted 2026-11-08. Nothing here exists yet. Companion to `HOMELAB.md`.

## Goal

Dave and I already pass notes over Signal. Bring the agent team into
that: `sec`'s memos, handoffs and gate requests arrive on our phones,
and we can reply to `sec` from Signal. The gates don't move: merges,
applies and new attack surface still need me at a keyboard, never a chat
message.

## Who's who

- **Me (lead):** maintainer of Blitz and the homelab, owner of every gate.
- **Dave:** second maintainer of Polar, collaborator on Blitz. In
  phase 2 Dave can give `sec` tasks and answer its questions, the same as
  me. Gate approvals stay mine (open question below for Polar-only gates).
- **The bot:** its own Signal number. Never linked to my personal account:
  a linked device sees every chat and can send as me, and anything that
  could prompt-inject an agent would inherit that.

## The bot's number

Registering a Signal account needs a captcha plus an SMS or voice code,
done once by me. Options, cheapest first:

| Option | Cost | Caveats |
|---|---|---|
| **Google Voice** | free (US) | Needs an existing US number to set up. Google reclaims numbers with no activity for ~3 months: send or receive something regularly. Signal generally accepts GV numbers. |
| **A landline / office line** | free if one exists | Use Signal's voice-call verification. |
| **Free ad-supported VoIP** (TextNow etc.) | free | Numbers recycle quickly after inactivity, and Signal blocks some VoIP ranges. Least reliable. |
| **Prepaid SIM** | ~$3–10/mo | Most robust; a real mobile number. |

**Never** use public "receive SMS online" sites: anyone can read the
code and register the number out from under us.

Whatever the number: turn on **Registration Lock** with a strong PIN
(kept in my password manager), so a recycled or hijacked number can't be
re-registered. The relay staying online keeps the account active, which
keeps the lock in force.

## Architecture

```
  phones (me, Dave) ── Signal group "rainbow-ops" ── bot number
                                                        │
                                   relay (Incus, no agent harness)
                                   signal-cli daemon + bridge script
                                                        │ T3 link (relay → sec)
                                                        ▼
                                                       sec ──▶ eng-app, test, jr
```

- **`relay`:** a small Incus instance from this flake (a new role, but
  with no Claude/Codex, no lane clone and no `/lead`). It runs:
  - `signal-cli` (nixpkgs, 0.14.9) as a daemon on the bot number, with its
    JSON-RPC socket local to the instance. Not siggy: siggy wraps the same
    signal-cli, isn't in nixpkgs, has one maintainer, and its bot mode
    only does substring triggers. (siggy as *my* terminal client in zellij
    is a separate, personal choice.)
  - a bridge script (nushell, small) that does the forwarding below.
- **State:** signal-cli's keys live on a persistent block volume
  (`home-relay`), like the agents' homes. They are credentials: never in
  the Nix store, never in a log, and the volume is snapshotted like the
  others.
- **Network:**
  - Egress: Signal's servers only. A hostname allowlist needs DNS-aware
    filtering. Phase 1 can start with "443 out, nothing else" and the
    host's bridge table blocking every VM-to-VM port except the one link.
  - The T3 link is `relay → sec`, the same down-only shape as the others,
    with `orchestration:read` + `orchestration:operate` at
    `approval-required` access. The relay never runs anything in `sec`;
    it only reads the thread and queues messages. A new pair in the
    `homelab-t3-links` table and a `t3Peers` entry.
  - Nothing can reach `relay`: no ingress, no pairing for the agents.

## Phases

### Phase 1: outbound only

Memos reach the phones; nothing reaches the agents.

- `sec` marks a message for Signal by starting it with `[memo]`
  (also `[gate]` for "a gate needs the lead", `[handoff]`). This goes in
  the Blitz lane rules (sec owns them).
- Every minute the bridge reads `sec`'s coordinator thread over the link
  (`t3 thread show --json`), and posts new marked messages to the group,
  trimmed to a length limit, with a link to the thread in the host T3.
- `sec` never puts secrets, tokens or credentials in a marked message
  (already a team rule; restated in the lane rules).

### Phase 2: inbound from an allowlist

- signal-cli delivers group messages to the bridge. It accepts only:
  the `rainbow-ops` group ID, and senders whose Signal ACIs (UUIDs, not
  phone numbers) are on the allowlist (me, Dave). Everything else is
  dropped and counted. Text only, no attachments, with a length cap and
  a rate limit.
- Accepted messages become **queued** turns in `sec`'s thread, tagged
  `[Signal, Vaughn]` or `[Signal, Dave]`. They never interrupt a turn.
- `sec` treats them as instructions from that person, inside the team
  rules. Pasted logs or links inside them are data, not instructions.
- A message can't approve a gate. `sec` answers "gate: needs the lead
  at a keyboard" and waits.

### Phase 3: commands

Answered by the relay itself, without an agent: `!status` (agents up,
current goal), `!pool` (the same feed as `homelab-pool`, which the host
can publish to `relay` too), `!help`.

## Threat model (short)

| Threat | Mitigation |
|---|---|
| Bot number recycled or hijacked | Registration Lock + PIN; relay always online |
| Someone else messages the bot | Group + sender ACI allowlist; dropped silently |
| Dave's or my phone compromised | Gates still need a keyboard; `sec` can only task within lanes; revoke by removing the ACI from the allowlist |
| Prompt injection via forwarded text | Tagged as from a person, pasted content is data; gates unchanged; `jr` can't be reached from Signal |
| Relay compromised | No agent harness, no repo, no `/lead`, one link at `approval-required`; keys only for the bot account |
| Secrets leaking to Signal | Team rule; bridge refuses messages matching gitleaks patterns (reuse `gitleaks` on the outbound text) |

## Build steps

1. Get the number; register it with signal-cli inside `relay`
   (`signal-cli -a +1… register --captcha …`, then `verify`), myself,
   since the codes are credentials. Set Registration Lock.
2. Add the `relay` role to `flake.nix` (`roles`), its `configuration.nix`
   under `hosts/rainbow/agents/relay/` (signal-cli service, bridge,
   `t3Peers.sec`), a pinned address, the link-table pair and egress rule
   in `homelab.nix`.
3. Create the `rainbow-ops` group with me, Dave and the bot; record the
   group ID and our ACIs in the bridge config (not secrets, but not
   public either: keep them in the relay's state, not this repo).
4. `link relay sec <port> approval-required`.
5. Phase 1 live; run it a week; then phase 2.

## Open questions

- Which number option (above)?
- Should Dave approve gates that only touch Polar? Today all gates are
  mine.
- Does the T3 mobile app (see `HOMELAB.md`, phone access) make phase 2
  less necessary? Signal is for the quick notes; the app for real
  sessions.
