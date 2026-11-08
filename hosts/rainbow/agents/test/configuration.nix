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
  imports = [ ../../../common/agent-vm.nix ../common/blitz-lane.nix ];

  homelab.agentVm = {
    role = "test";
    description = "Test engineer";
    # Down-only links (HOMELAB.md "Team"): test hands low-risk work to jr.
    t3Peers.jr = { address = "10.80.0.50"; localPort = 47302; };
    # builder-cargo.sh puts its target dir in $HOME, outside /work.
    codexWritableRoots = [ "/home/agent/blitz-target-test" ];
    # Testcontainers finds the runtime through DOCKER_HOST.
    environment.DOCKER_HOST = "unix:///run/user/1000/podman/podman.sock";
  };

  # --- Container runtime for the testcontainers suites ---------------------
  # Rootless podman inside this VM. Not the host's podman: its socket would
  # be root on rainbow. The VM stays the containment boundary.
  virtualisation.podman.enable = true;
  # The agent user's podman API socket, up without anyone logged in.
  users.users.agent.linger = true;
  systemd.user.sockets.podman.wantedBy = [ "sockets.target" ];
  # Container storage on the 30 GiB root disk, not the 10 GiB home volume:
  # it's only a cache, so losing it on a re-roll is fine.
  virtualisation.containers.storage.settings.storage.rootless_storage_path =
    "/var/lib/containers-rootless/$USER";
  systemd.tmpfiles.rules = [ "d /var/lib/containers-rootless 0755 root root -" "d /var/lib/containers-rootless/agent 0700 agent users -" ];

  # Housekeeping (HOMELAB.md "Housekeeping"): the Incus pool has no room
  # for container leftovers. Hourly, drop stopped containers, unused
  # volumes and dangling images; daily, every image no container uses.
  systemd.services.agent-podman-prune = {
    description = "Prune the agent user's stopped containers and unused images";
    serviceConfig = {
      Type = "oneshot";
      User = "agent";
      Group = "users";
      Environment = "XDG_RUNTIME_DIR=/run/user/1000";
    };
    path = [ pkgs.podman ];
    script = ''
      podman container prune --force
      podman volume prune --force
      podman image prune --force
      if [ "$(date +%H)" = 03 ]; then podman image prune --all --force; fi
    '';
    startAt = "hourly";
  };

  environment.systemPackages = with pkgs; [
    claude-code
    codex
    # The stack-check scripts in Blitz src/scripts.
    python3
  ];
}
