# test — Test engineer agent VM image.
#
# Checks independently that the work actually works. Eng tests its own
# code and sec reviews for security; neither is an outside check of
# behaviour, and that's this role's job. In Blitz this is the test lane:
# integration and end-to-end suites, load tests, the stack checks, and
# checking each release candidate, including that the manuals' procedures
# still do what they say. Unit tests stay with whoever writes the code;
# sec owns the pipeline that runs the suites.
#
# Its lane clone is mounted read-write at /work, e.g. `test` ↔
# ../blitz-test. Test tooling (k6 etc.) belongs in the project's own
# flake, not this image, so CI and this VM run the same versions.
#
# Tasks come from sec; questions go back to sec. It hands grunt work
# (fixtures, scaffolding) down to jr.
{ pkgs, ... }:
{
  imports = [ ../../../common/agent-vm.nix ];

  homelab.agentVm = {
    role = "test";
    description = "Test engineer";
    # Down-only links (HOMELAB.md "Team"): test hands low-risk work to jr.
    t3Peers.jr = { address = "10.80.0.50"; localPort = 47302; };
  };

  environment.systemPackages = with pkgs; [
    claude-code
    codex
  ];
}
