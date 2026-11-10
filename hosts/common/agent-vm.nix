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

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = { OPENCODE_CONFIG = "/etc/opencode/opencode.json"; };
      description = ''
        Variables for the harnesses: set on t3-serve (whose children are the
        agent sessions) and in login shells, so `incus exec … su - agent`
        sees the same configuration T3 does. Public — no secrets.
      '';
    };

    t3Settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = { linkedEnvironmentsEnabled = true; };
      description = ''
        Keys merged into T3's server settings (~/.t3/userdata/settings.json)
        each time t3-serve starts. Keys set here win; everything else in the
        file, including what's changed in the UI, is kept.
      '';
    };

    t3Peers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          address = lib.mkOption {
            type = lib.types.str;
            description = "Peer instance's pinned bridge address.";
          };
          localPort = lib.mkOption {
            type = lib.types.port;
            description = "Loopback port in this VM that forwards to the peer's T3.";
          };
        };
      });
      default = { };
      example = { jr = { address = "10.80.0.50"; localPort = 47302; }; };
      description = ''
        T3 environments this VM's agents may link to (`t3 environment link
        http://127.0.0.1:<localPort>`). T3 only links over plain http to
        loopback or Tailscale addresses, so each peer gets a loopback
        forwarder. The link token crosses the host-internal bridge
        unencrypted. Which links are allowed at all is enforced on the host
        (hosts/rainbow/homelab.nix), not here.
      '';
    };

    tailscale = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Join the tailnet and have T3 publish itself with Tailscale Serve
        (HTTPS on <role>.<tailnet>.ts.net), so the T3 mobile app and other
        tailnet devices can reach it. `--lan` stays on for the desktop
        pairings. Node state lives on the home volume, so a re-roll keeps
        the identity. The first join is interactive (HOMELAB.md, phone
        access); the tailnet ACL decides who reaches it.
      '';
    };

    codexWritableRoots = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/home/agent/blitz-target-app" ];
      description = ''
        Extra paths Codex's `workspace-write` sandbox may write, on top of
        the shared defaults (the lane's `.git`, ~/.cargo, ~/.cache). Lane
        build dirs outside ${cfg.workDir} go here.
      '';
    };

    persistentHome = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Expect an Incus *block* custom volume attached as a disk device named
        `home`, and mount it at /home/agent, so harness logins, T3 pairing
        and links survive an image re-roll. Formatted ext4 on first boot. A
        block volume, not a filesystem volume: those reach a VM over
        virtiofs, where SQLite's WAL mode (T3's state) fails with "disk I/O
        error".
      '';
    };
  };

  config = lib.mkMerge [ {
    # Agents coordinate through T3 environment links (HOMELAB.md "Team").
    homelab.agentVm.t3Settings.linkedEnvironmentsEnabled = lib.mkDefault true;

    networking.hostName = lib.mkDefault cfg.role;
    time.timeZone = lib.mkDefault "America/New_York";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    # Guest-side Incus agent — without it the instance boots but Incus
    # reports "VM agent isn't currently running" and `incus exec` fails.
    virtualisation.incus.agent.enable = true;

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "agent" ];
      # Housekeeping (HOMELAB.md "Housekeeping"): the root disk is 30 GiB
      # and the whole Incus pool is a 100 GiB loop file shared by every VM.
      # Collect garbage during builds whenever free space drops below 3 GiB,
      # until 10 GiB is free. eng-app hit 94% on 2026-11-08 without this.
      min-free = 3 * 1024 * 1024 * 1024;
      max-free = 10 * 1024 * 1024 * 1024;
      # The agent profile caps a VM at 4 vCPUs and 8 GiB. Unlimited parallel
      # builds got nix-daemon OOM-killed on test (2026-11-08, building
      # ACE's dev shell with a nightly Rust toolchain). Two jobs of two
      # cores each fit the CPU cap and leave memory for the harnesses.
      max-jobs = 2;
      cores = 2;
      # A rooted dev shell (`nix develop --profile`) then also keeps the
      # build inputs behind it, so a GC can't force a re-download of the
      # ~5 GiB Blitz `ci` shell (sec, 2026-11-08).
      keep-outputs = true;
      keep-derivations = true;
    };
    # And a weekly sweep of dead paths, so idle VMs give space back too.
    nix.gc = {
      automatic = true;
      dates = "weekly";
    };
    # Freed blocks only return to the host pool once the guest discards
    # them; without this, deleting inside a VM never shrinks the pool.
    # Hourly: a daily trim left a 5 GiB delete on test uncounted for 30+
    # minutes with the pool at 77% (2026-11-08). The pool-pressure GC
    # below also trims right after collecting.
    services.fstrim = {
      enable = true;
      interval = "hourly";
    };
    # Online discard: ext4 discards blocks as files are deleted, so the
    # pool shrinks immediately instead of at the next trim. The hourly trim
    # couldn't keep up with builds: they free 5-8 GiB an hour, and the pool
    # sat above 80% between trims until sec and test stopped work
    # (2026-11-10, 83.7 GiB used; a manual trim recovered 8.5 GiB). The disks
    # are files in the pool, so the cost of a synchronous discard is small.
    # fstrim stays as a backstop: online discard can skip small extents.
    # The incus VM module defines "/"; this list merges into its options.
    fileSystems."/".options = [ "discard" ];

    # Give RAM back to the host. Guest RAM is memfd-backed (virtiofs needs
    # shared memory), so the host can't reclaim a guest's page cache, and
    # KSM can't merge it. Each VM sat at ~6 GiB host RSS with ~1.7 GiB
    # actually in use (2026-11-08). With the balloon's free-page reporting
    # on (Incus `balloon` profile), pages the guest frees go back to the
    # host within seconds: dropping a filled cache took one VM from
    # 5.4 GiB to 2.0 GiB. The cache only duplicates the host's own cache
    # of the same disk files, so drop clean page cache every 10 minutes.
    # The host publishes the Incus pool's usage into each VM's config
    # (`user.homelab.pool`, hosts/rainbow/homelab.nix); read it through the
    # guest API (/dev/incus/sock, root only) into a world-readable file, and
    # log a warning past 80%. `homelab-pool` prints it.
    #
    # Under pool pressure (warn, 80%+) it also collects this VM's Nix
    # garbage and trims, at most every 30 minutes. `min-free` can't do
    # this: it measures the VM's own thin disk, which looks free while the
    # pool fills. Only unrooted paths go; lanes keep their dev shell with
    # `nix develop --profile ~/.local/state/nix/profiles/<name>` (HOMELAB.md
    # "Housekeeping"). Agents themselves don't run store-wide GC.
    systemd.services.homelab-pool-status = {
      description = "Copy the host's Incus pool status into /run/homelab/pool";
      serviceConfig.Type = "oneshot";
      path = [ pkgs.curl pkgs.coreutils pkgs.systemd pkgs.util-linux config.nix.package ];
      script = ''
        mkdir -p /run/homelab
        s=$(curl -sf --unix-socket /dev/incus/sock \
          http://incus/1.0/config/user.homelab.pool) || exit 0
        printf '%s\n' "$s" > /run/homelab/pool.tmp
        chmod 0644 /run/homelab/pool.tmp
        mv /run/homelab/pool.tmp /run/homelab/pool
        case "$s" in
          *status=warn*|*status=critical*)
            echo "Incus pool is filling: $s. Prune build dirs, containers and the Nix store." \
              | systemd-cat -t homelab -p warning
            stamp=/run/homelab/last-pressure-gc
            if [ ! -e "$stamp" ] || [ $(( $(date +%s) - $(stat -c %Y "$stamp") )) -ge 1800 ]; then
              touch "$stamp"
              freed=$(nix-store --gc 2>&1 | tail -1)
              fstrim -a >/dev/null 2>&1 || true
              echo "pool-pressure GC: $freed; trimmed" | systemd-cat -t homelab -p notice
            fi ;;
        esac
      '';
      startAt = "*:0/2";
    };

    systemd.services.guest-cache-drop = {
      description = "Drop clean page cache so free-page reporting returns it to the host";
      serviceConfig.Type = "oneshot";
      script = "echo 1 > /proc/sys/vm/drop_caches";
      startAt = "*:0/10";
    };

    # Codex's workspace-write sandbox makes `.git` read-only inside writable
    # roots, so agents can't commit, and it blocks cargo's caches outside
    # the lane and the network cargo needs. The VM is the containment
    # boundary; this keeps the sandbox protecting what matters inside it
    # (~/.codex, ~/.claude, shell rc files, T3 state) instead of running
    # at full access. Codex reads /etc/codex/config.toml as its system
    # layer; ~/.codex/config.toml still wins key by key.
    environment.etc."codex/config.toml".source =
      (pkgs.formats.toml { }).generate "codex-config.toml" {
        sandbox_workspace_write = {
          writable_roots = [
            "${cfg.workDir}/.git"
            "/home/agent/.cargo"
            "/home/agent/.cache"
          ] ++ cfg.codexWritableRoots;
          network_access = true;
        };
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

    environment.sessionVariables = cfg.environment;

    # Declarative replacement for `t3 serve --lan` in a zellij pane (and for
    # `t3 service install`, which would write a unit outside Nix). State
    # lives in the agent user's default T3 home, so `t3 pair` run as
    # `agent` finds this server.
    systemd.services.t3-serve = {
      description = "T3 Code server (${cfg.role})";
      wantedBy = [ "multi-user.target" ];
      # incus-agent mounts disk devices; start after it so ${cfg.workDir}
      # is the real worktree, not the empty placeholder.
      after = [ "network-online.target" "incus-agent.service" ]
        ++ lib.optional cfg.persistentHome "agent-home.service"
        ++ lib.optional cfg.tailscale "tailscaled.service";
      wants = [ "network-online.target" ]
        ++ lib.optional cfg.tailscale "tailscaled.service";
      requires = lib.optional cfg.persistentHome "agent-home.service";
      # Harnesses spawned by T3 need git, nix, sudo and themselves on PATH.
      path = [ "/run/wrappers" "/run/current-system/sw" ];
      inherit (cfg) environment;
      # Merge declared settings into T3's settings file (runs as agent).
      preStart = lib.optionalString (cfg.t3Settings != { }) ''
        f="$HOME/.t3/userdata/settings.json"
        mkdir -p "$(dirname "$f")"
        [ -s "$f" ] || echo '{}' > "$f"
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$f" \
          ${pkgs.writeText "t3-settings.json" (builtins.toJSON cfg.t3Settings)} \
          > "$f.tmp" && mv "$f.tmp" "$f"
      '';
      serviceConfig = {
        User = "agent";
        Group = "users";
        WorkingDirectory = cfg.workDir;
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.t3code}/bin/t3 serve"
          "--lan"
          "--no-browser"
          "--port ${toString cfg.t3Port}"
        ]
        # Publishes https://<role>.<tailnet>.ts.net via `tailscale serve`.
        # If Tailscale isn't logged in yet, T3 logs "Failed to configure
        # Tailscale Serve" and keeps serving on --lan (tested 2026-11-08);
        # restart t3-serve after the first join.
        + lib.optionalString cfg.tailscale " --tailscale-serve"
        + " ${cfg.workDir}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Persistent home: Incus names the guest disk after the device
    # (`home` -> ...incus_home). autoFormat makes a fresh volume ext4 on first
    # boot; nofail keeps the VM bootable without one, but agent-home (and so
    # t3-serve) then fails instead of writing state to the throwaway root.
    fileSystems."/home/agent" = lib.mkIf cfg.persistentHome {
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_home";
      fsType = "ext4";
      autoFormat = true;
      # discard: see services.fstrim above.
      options = [ "nofail" "x-systemd.device-timeout=30s" "discard" ];
    };

    # A freshly formatted volume's root is root-owned; hand it to agent.
    systemd.services.agent-home = lib.mkIf cfg.persistentHome {
      description = "Prepare the persistent /home/agent volume";
      requires = [ "home-agent.mount" ];
      after = [ "home-agent.mount" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.coreutils ];
      script = ''
        if [ "$(stat -c %u /home/agent)" != 1000 ]; then
          chown agent:users /home/agent
          chmod 0700 /home/agent
        fi
      '';
    };

    environment.systemPackages = with pkgs; [
      vim
      git
      jq
      # Tools Blitz's scripts and checks call (sec's memo, 2026-11-08). From
      # this repo's nixpkgs, whose versions match Blitz's pin except nufmt,
      # which Blitz's own flake provides, so formatting matches CI exactly.
      # Toolchains (Rust, ACE's shell) stay in the project flakes.
      nushell
      nu-lint
      ripgrep
      dhall-json
      (writeShellScriptBin "homelab-pool" ''
        # The shared Incus pool's real usage. `df` here only sees this VM's
        # thin disk, which can show free space while the pool is full.
        cat /run/homelab/pool 2>/dev/null || echo "no pool status yet (published by the host every 2 min)"
      '')
      # Spare shell panes for poking at the VM; T3 itself no longer needs one.
      zellij
      t3code
    ];

    system.stateVersion = lib.mkDefault "25.05";
  }
  (lib.mkIf cfg.tailscale {
    services.tailscale = {
      enable = true;
      # T3 runs as `agent` and configures `tailscale serve` itself.
      extraSetFlags = [ "--operator=agent" ];
      disableTaildrop = true;
    };
    # Node identity on the home volume, so a re-roll doesn't create a new
    # tailnet device (and a new login). Root-only, inside agent's home.
    systemd.services.tailscaled = lib.mkIf cfg.persistentHome {
      after = [ "agent-home.service" ];
      requires = [ "agent-home.service" ];
      serviceConfig.BindPaths = [ "/home/agent/.local/state/tailscale:/var/lib/tailscale" ];
    };
    systemd.services.agent-home.script = lib.mkIf cfg.persistentHome (lib.mkAfter ''
      [ -d /home/agent/.local ] || install -d -o agent -g users /home/agent/.local
      [ -d /home/agent/.local/state ] || install -d -o agent -g users /home/agent/.local/state
      install -d -m 0700 -o root -g root /home/agent/.local/state/tailscale
    '');
  })
  {
    # Loopback forwarders for T3 links (see the t3Peers option).
    systemd.sockets = lib.mapAttrs' (name: peer:
      lib.nameValuePair "t3-peer-${name}" {
        description = "Loopback forwarder to ${name}'s T3";
        wantedBy = [ "sockets.target" ];
        listenStreams = [ "127.0.0.1:${toString peer.localPort}" ];
      }) cfg.t3Peers;
    systemd.services = lib.mapAttrs' (name: peer:
      lib.nameValuePair "t3-peer-${name}" {
        description = "Loopback forwarder to ${name}'s T3";
        requires = [ "t3-peer-${name}.socket" ];
        after = [ "t3-peer-${name}.socket" ];
        serviceConfig = {
          ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd ${peer.address}:${toString cfg.t3Port}";
          DynamicUser = true;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      }) cfg.t3Peers;
  } ];
}
