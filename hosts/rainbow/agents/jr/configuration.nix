# jr — Junior engineer agent VM image (OpenCode + a local model).
#
# Takes the lowest-risk tasks the lead forwards: small fixes, lint
# cleanups, test scaffolding, second-opinion reviews where a miss is
# cheap. Works in its own worktree at /work like the other roles, but
# its model runs locally — gemma4:12b (Q4_K_M, ~8 GB) via Ollama's
# OpenAI-compatible endpoint — so it needs no frontier API credentials
# and its egress can be limited to the model server alone.
#
# OpenCode's provider config is per-user state for now, not baked in
# here (see HOMELAB.md "Model server").
#
# Tasks come from the lead; questions go back to the lead.
{ pkgs, ... }:
{
  imports = [ ../../../common/agent-vm.nix ];

  homelab.agentVm = {
    role = "jr";
    description = "Junior engineer";
  };

  environment.systemPackages = with pkgs; [
    opencode
  ];
}
