# Shared base for homelab agent VM images (see hosts/rainbow/HOMELAB.md).
#
# Not imported by any host. Each role under hosts/<host>/agents/<role>/
# imports this and sets `homelab.agentVm.*` plus its own harness packages.
# The flake's `mkAgent` adds the upstream `incus-virtual-machine` module
# that turns the result into a qcow2 + metadata tarball for `incus image
# import`.
#
# What every role gets:
#   - an unprivileged-by-default `agent` user (uid 1000 to match host bind
#     mounts) that the harnesses run as
#   - the guest incus-agent, so `incus exec` works
#   - SSH off; T3's bearer-gated server on 3773 is the only ingress
#   - `t3-serve.service`, so T3 comes back after a reboot or a closed pane
{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.agentVm;
in
{
  options.homelab.agentVm = {
    role = lib.mkOption {
      type = lib.types.str;
      example = "eng";
      description = "Role name. Used as the default hostname and Incus instance name.";
    };

    description = lib.mkOption {
      type = lib.types.str;
      example = "Backend/systems engineer";
      description = "Human-readable role, shown as the agent user's GECOS.";
    };

    workDir = lib.mkOption {
      type = lib.types.str;
      default = "/work";
      description = ''
        Where the role's worktree is mounted (an Incus disk device) and the
        working directory T3 starts provider sessions in.
      '';
    };

    t3Port = lib.mkOption {
      type = lib.types.port;
      default = 3773;
      description = "Port `t3 serve` listens on; opened in the guest firewall.";
    };
  };

  config = {
    networking.hostName = lib.mkDefault cfg.role;
    time.timeZone = lib.mkDefault "America/New_York";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    # Guest-side Incus agent — without it the instance boots but Incus
    # reports "VM agent isn't currently running" and `incus exec` fails.
    virtualisation.incus.agent.enable = true;

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "agent" ];
    };

    # Non-root user. T3's browser sandbox doesn't work as root, and running
    # the harnesses under their own account keeps the blast radius small.
    # uid pinned to 1000 so host bind mounts (vcaaron, also 1000) are
    # writable without idmap gymnastics.
    #
    # Password is locked: `incus exec <vm> -- su - agent` needs none, SSH is
    # off, and a known default password ("agent") was the only thing a
    # console login would have asked for.
    users.users.agent = {
      isNormalUser = true;
      inherit (cfg) description;
      extraGroups = [ "wheel" ];
      uid = 1000;
      hashedPassword = "!";
    };
    # The VM is the containment boundary, not the agent user. Passwordless
    # sudo lets the harness `nix profile install` / fix the guest itself.
    security.sudo.wheelNeedsPassword = false;

    # Mount point for the role's worktree. The Incus disk device mounts over
    # it; the tmpfiles rule just guarantees T3 has a directory to start in
    # when no device is attached yet.
    systemd.tmpfiles.rules = [ "d ${cfg.workDir} 0755 agent users -" ];

    # The pairing URL points at the VM's bridge IP. The bridge has no
    # external route — only rainbow and other `dev` instances reach it — so
    # opening the port in the guest doesn't widen rainbow's external attack
    # surface. T3's bearer still gates anything that reaches the socket.
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ cfg.t3Port ];
    };

    services.openssh.enable = false;

    # Declarative replacement for `t3 serve --lan` in a zellij pane (and for
    # `t3 service install`, which would write a unit outside Nix). State
    # lives in the agent user's default T3 home, so `t3 pair` run as
    # `agent` finds this server.
    systemd.services.t3-serve = {
      description = "T3 Code server (${cfg.role})";
      wantedBy = [ "multi-user.target" ];
      # incus-agent mounts disk devices; start after it so ${cfg.workDir}
      # is the real worktree, not the empty placeholder.
      after = [ "network-online.target" "incus-agent.service" ];
      wants = [ "network-online.target" ];
      # Harnesses spawned by T3 need git, nix, sudo and themselves on PATH.
      path = [ "/run/wrappers" "/run/current-system/sw" ];
      serviceConfig = {
        User = "agent";
        Group = "users";
        WorkingDirectory = cfg.workDir;
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.t3code}/bin/t3 serve"
          "--lan"
          "--no-browser"
          "--port ${toString cfg.t3Port}"
          cfg.workDir
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    environment.systemPackages = with pkgs; [
      vim
      git
      jq
      # Spare shell panes for poking at the VM; T3 itself no longer needs one.
      zellij
      t3code
    ];

    system.stateVersion = lib.mkDefault "25.05";
  };
}
