# eng — Backend/systems engineer agent VM image.
#
# Writes code. In Blitz this is the implementation lanes (B: application
# + infra sources; C: engine and model when it's active). One instance
# per active lane, each launched from this image with that lane's
# worktree mounted read-write at /work, e.g. `eng-app` ↔ ../blitz-app.
#
# Tasks come from the lead (the maintainer); questions go back to the
# lead. Snapshot before each task so a bad run is a `snapshot restore`.
{ pkgs, ... }:
{
  imports = [ ../../../common/agent-vm.nix ];

  homelab.agentVm = {
    role = "eng";
    description = "Backend/systems engineer";
    # Down-only links (HOMELAB.md "Team"): eng hands low-risk work to jr.
    # Instance-specific for now (eng-app); a second eng lane would need
    # its own peer set.
    t3Peers.jr = { address = "10.80.0.50"; localPort = 47302; };
    # builder-cargo.sh puts its target dir in $HOME, outside /work. Lane
    # `app` (eng-app); a second eng lane would need its own entry.
    codexWritableRoots = [ "/home/agent/blitz-target-app" ];
  };

  # Frontier harnesses. Both are installed so the lead can compare models
  # per thread from T3; only the ones logged in inside this VM are usable.
  environment.systemPackages = with pkgs; [
    claude-code
    codex
  ];
}
