# jr — Junior engineer agent VM image (OpenCode + a local model).
#
# Takes the lowest-risk tasks the lead forwards: small fixes, lint
# cleanups, test scaffolding, second-opinion reviews where a miss is
# cheap. Works in its own clone at /work like the other roles, but its
# model runs locally — gemma4:12b (Q4_K_M, ~8 GB) via Ollama's
# OpenAI-compatible endpoint — so it needs no frontier API credentials
# and no internet egress at all.
#
# Until `infer` exists, the endpoint is the host's Ollama, reached
# through a bridge-only proxy that admits jr's pinned address alone
# (hosts/rainbow/homelab.nix). Launch with:
#   incus config device override jr eth0 ipv4.address=10.80.0.50 --project dev
#
# Tasks come from the lead; questions go back to the lead.
{ pkgs, ... }:
let
  ollamaBaseURL = "http://10.80.0.1:11434/v1";
  model = "gemma4:12b";

  # Baked OpenCode config (no per-user state to set up after a re-roll).
  # The OpenAI-compatible adapter is bundled in the package — verified it
  # makes no npm fetch at runtime — so this works with egress blocked.
  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    # Nix owns the version; no self-update, no public share links.
    autoupdate = false;
    share = "disabled";
    # Only the local model. OpenCode also offers hosted "opencode/*" models;
    # jr has no internet, so hide them rather than let an agent pick one.
    enabled_providers = [ "ollama" ];
    provider.ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama (rainbow)";
      options.baseURL = ollamaBaseURL;
      models.${model} = {
        name = "Gemma 4 12B";
        tools = true;
      };
    };
    model = "ollama/${model}";
  };
in
{
  imports = [ ../../../common/agent-vm.nix ];

  homelab.agentVm = {
    role = "jr";
    description = "Junior engineer";
    environment.OPENCODE_CONFIG = "/etc/opencode/opencode.json";
    # T3 providers are opt-in; jr's only harness is OpenCode.
    t3Settings.providerInstances.opencode = { driver = "opencode"; enabled = true; };
  };

  environment.etc."opencode/opencode.json".text = builtins.toJSON opencodeConfig;

  # nixpkgs' opencode 2.2.5 fails to build at our pin: the expected hash
  # of its node_modules download no longer matches what upstream serves.
  # Correct it here, scoped to this image only. Remove once nixpkgs ships
  # a fixed hash (try: drop this overlay, `nix build .#jr-image-disk`).
  nixpkgs.overlays = [
    (final: prev: {
      opencode = prev.opencode.overrideAttrs (old: {
        node_modules = old.node_modules.overrideAttrs {
          outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
        };
      });
    })
  ];

  environment.systemPackages = [ pkgs.opencode ];
}
