# sec — DevSecOps engineer agent VM image. The lead's right hand.
#
# Goals: maximize DSO process performance; maximize the lead's (customer/
# user) satisfaction. It writes, not just reviews: CI/pipeline, config,
# hardening, process docs, findings, and task proposals for other roles.
# See HOMELAB.md "Roles → sec" for its core questions and responsibilities.
#
# Mounts (Incus disk devices; read-only is enforced by `readonly=true`,
# not by agent settings — verify a write from inside fails):
#   /work    its own lane worktree, read-write (Blitz lane D,
#            ../blitz-hardening). Findings and proposed tasks land here.
#   /lead    the lead's main checkout, read-only. Every lane branch,
#            handoff and request is readable with `git show
#            lane/<x>:<path>`, so it can see across lanes without
#            writing to any of them.
#   /review  (optional) a specific branch under review, read-only.
#
# It proposes handoffs to other roles; it never dispatches them. The lead
# approves each one and relays it.
{ pkgs, ... }:
{
  imports = [ ../../../common/agent-vm.nix ];

  homelab.agentVm = {
    role = "sec";
    description = "DevSecOps engineer";
    # Down-only links (HOMELAB.md "Team"): sec coordinates eng, test and jr.
    t3Peers = {
      eng-app = { address = "10.80.0.126"; localPort = 47301; };
      jr = { address = "10.80.0.50"; localPort = 47302; };
      test = { address = "10.80.0.60"; localPort = 47303; };
    };
  };

  environment.systemPackages = with pkgs; [
    claude-code
    codex
  ];
}
