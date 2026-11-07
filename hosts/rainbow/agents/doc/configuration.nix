# doc — Technical writer agent VM image.
#
# Updates the docs. In Blitz this is lane E: the user manual
# (docs/manual/, docs/manual-editorial/, scripts/manual/), mounted
# read-write at /work from ../blitz-manual. Other lanes hand it changes
# that alter something a manual states; it documents only what has been
# observed.
#
# Tasks come from the lead; questions go back to the lead.
{ pkgs, ... }:
{
  imports = [ ../../../common/agent-vm.nix ];

  homelab.agentVm = {
    role = "doc";
    description = "Technical writer";
  };

  environment.systemPackages = with pkgs; [
    claude-code
    codex
  ];
}
