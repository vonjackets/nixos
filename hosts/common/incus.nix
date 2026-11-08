# Optional module: Incus for disposable system containers and VMs.
# Imported explicitly by hosts that want it (like k3s.nix), not baked into
# sharedModules — it runs a daemon, owns a bridge, and changes the host's
# firewall backend.
#
#   incus launch images:nixos/unstable scratch            # system container (shared kernel)
#   incus launch images:ubuntu/24.04 box --vm             # full VM (own kernel, stronger isolation)
#   incus launch images:debian/13 a1 -p default -p agent  # resource-capped agent sandbox
#   incus launch images:debian/13 a2 -p default -p agent -p sealed  # ...with no network at all
#   incus snapshot create a1 clean && incus snapshot restore a1 clean
#   incus launch ... --ephemeral                          # deleted on stop
{ ... }:
{
  virtualisation.incus = {
    enable = true;

    # Applied on every incus start; creates/updates these objects.
    preseed = {
      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.80.0.1/24";
            "ipv4.nat" = "true";
            "ipv6.address" = "none";
            # Dynamic leases from .100 up; .2-.99 are for instances pinned
            # with `ipv4.address` (see hosts/rainbow/homelab.nix).
            "ipv4.dhcp.ranges" = "10.80.0.100-10.80.0.254";
          };
        }
      ];

      # btrfs on a sparse loop file: root is ext4, and the `dir` driver would
      # make every snapshot/copy a full rsync. btrfs gives instant CoW clones,
      # which is the point of a disposable-machine workflow. `size` is a
      # ceiling; the backing file only grows as data is written.
      storage_pools = [
        {
          name = "default";
          driver = "btrfs";
          config.size = "100GiB";
        }
      ];

      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              network = "incusbr0";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
          };
        }
        {
          # Stack on top of `default` for agent sandboxes: keeps a runaway
          # agent from starving the desktop, games, or k3s.
          name = "agent";
          config = {
            "limits.cpu" = "4";
            # 0-10, default 10. Three agents at 4 vCPUs each cover all 12
            # host threads; under contention the desktop, games and k3s win.
            # Applies live to running VMs.
            "limits.cpu.priority" = "4";
            "limits.memory" = "8GiB";
            # VM instances booting unsigned images (nixos/unstable,
            # debian/13, ...) can't satisfy secureboot. Containers ignore
            # this key, so it's safe to leave on the shared profile.
            "security.secureboot" = "false";
          };
          devices.root = {
            path = "/";
            pool = "default";
            type = "disk";
            size = "30GiB";
          };
        }
        {
          # Stack on VMs so memory they free goes back to the host (the
          # balloon's free-page reporting; Incus leaves it off). Pairs with
          # the guest-side page-cache drop in agent-vm.nix. A profile of its
          # own because raw.qemu.conf can't change while a VM using it runs:
          # folding it into `agent` would fail the preseed on every switch
          # with agents up. Verified 2026-11-08: feature bit 5 set in the
          # guest; host RSS fell 5.4 -> 2.0 GiB after a cache drop.
          name = "balloon";
          config."raw.qemu.conf" = ''
            [device "qemu_balloon"]
            free-page-reporting = "on"
          '';
        }
        {
          # Stack last to strip networking entirely (overrides eth0).
          name = "sealed";
          devices.eth0.type = "none";
        }
      ];

      # Scoped project for the homelab plan (see HOMELAB.md). Shares profiles
      # with the default project so `agent` / `sealed` are usable here without
      # redefining them; images and storage volumes stay project-local.
      projects = [
        {
          name = "dev";
          description = "Agent homelab — one Incus instance per role.";
          config = {
            "features.profiles" = "false";
          };
        }
      ];
    };
  };

  # Incus on NixOS requires the nftables firewall backend (module assertion).
  # With stateVersion >= 23.11, flushRuleset defaults to false, so the NixOS
  # firewall only manages its own table and leaves rules written by k3s and
  # podman (iptables-nft) intact across reloads.
  networking.nftables.enable = true;

  # Instances need DHCP + DNS from incus's dnsmasq on the bridge. Allow only
  # that, rather than trustedInterfaces, so sandboxes can't reach host
  # services (sshd, k3s API, ollama, podman socket, ...).
  networking.firewall.interfaces.incusbr0 = {
    allowedUDPPorts = [ 53 67 ];
    allowedTCPPorts = [ 53 ];
  };

  # incus-admin is root-equivalent on the host (same class as the podman
  # docker socket). Don't add other users casually.
  users.users.vcaaron.extraGroups = [ "incus-admin" ];
}
