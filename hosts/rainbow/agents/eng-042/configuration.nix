# eng-042 — Engineer agent VM image.
#
# Built by the `eng-042-image-disk` / `eng-042-image-metadata` flake
# outputs via the upstream `incus-virtual-machine` module. Imported into
# Incus as a VM image; instances launched from it inherit this exact set
# of packages, users, and settings.
#
# This role actually WRITES to the repo — launch it with a writable disk
# device mapping a per-task worktree at /work (see HOMELAB.md runbook).
# Snapshot before each task so a bad run is a `snapshot restore` away.
#
# Note: once a third agent role lands (sec-042), factor the shared bits
# (user, flakes, firewall, incus agent, sshd=off) into
# `hosts/rainbow/agents/common.nix` and import from here.
{ pkgs, lib, ... }:
{
  networking.hostName = lib.mkDefault "eng-042";
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  virtualisation.incus.agent.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "agent" ];
  };

  users.users.agent = {
    isNormalUser = true;
    description = "Engineer agent";
    extraGroups = [ "wheel" ];
    uid = 1000;
    initialPassword = "agent";
  };
  security.sudo.wheelNeedsPassword = false;

  # See arch's firewall comment — same rationale applies.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 3773 ];
  };
  services.openssh.enable = false;

  environment.systemPackages = with pkgs; [
    vim
    git
    jq
    zellij
    # The agents themselves. Engineer uses Codex; a second-opinion review
    # can still flow through this VM via `t3 pair` if we point another
    # client at it.
    t3code
    codex
  ];

  system.stateVersion = "25.05";
}
