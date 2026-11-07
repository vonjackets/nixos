# Host-side pieces of the rainbow homelab (see HOMELAB.md) that are
# specific to this machine's agent instances, as opposed to the generic
# Incus base in ../common/incus.nix.
#
# Attack-surface summary (AGENTS.md asks for this to be explicit):
#   + opens TCP 11434 on incusbr0 only, and only to jr's pinned address
#     (10.80.0.50), via a proxy that forwards to Ollama on 127.0.0.1
#   - removes all internet egress from jr (it only needs the proxy)
# Nothing changes on the LAN-facing interfaces.
{ config, pkgs, ... }:
let
  bridgeAddr = "10.80.0.1";
  ollamaPort = 11434;

  # Pinned instance addresses live below the DHCP pool (.100-.254, set in
  # ../common/incus.nix). Applied per instance with:
  #   incus config device override <name> eth0 ipv4.address=<addr> --project dev
  jrAddr = "10.80.0.50";
in
{
  # --- jr -> Ollama ------------------------------------------------------
  # Stopgap until `infer` exists: jr's OpenCode talks to the host's Ollama.
  # Ollama itself stays bound to 127.0.0.1 (nothing else on the host, or
  # Blitz's in-cluster Ollama, changes). A socket-activated
  # systemd-socket-proxyd listens on the bridge address only and forwards.
  # When gamemode stops ollama.service, connections just fail until it's
  # back.
  systemd.sockets.ollama-bridge = {
    description = "Ollama proxy for homelab agents on incusbr0";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "${bridgeAddr}:${toString ollamaPort}" ];
    # incusbr0 is created by the Incus daemon, which can come up after
    # sockets.target. FreeBind lets the socket bind before the address
    # exists instead of failing at boot.
    socketConfig.FreeBind = true;
  };

  systemd.services.ollama-bridge = {
    description = "Ollama proxy for homelab agents on incusbr0";
    requires = [ "ollama-bridge.socket" ];
    after = [ "ollama-bridge.socket" "ollama.service" ];
    serviceConfig = {
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString ollamaPort}";
      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      CapabilityBoundingSet = "";
    };
  };

  # Only jr may reach the proxy. Other agent VMs share the bridge, so this
  # is per-source, not per-interface. (Spoofing caveat: another instance
  # could claim jr's address; see HOMELAB.md TODO on ipv4_filtering.)
  networking.firewall.extraInputRules = ''
    iifname "incusbr0" ip saddr ${jrAddr} tcp dport ${toString ollamaPort} accept
  '';

  # --- jr egress lockdown -------------------------------------------------
  # jr runs a local model and needs nothing from the internet. Drop any
  # *new* forwarded connection from it; replies to connections made *to*
  # jr (e.g. a T3 client) still pass. Its own table and base chain, so the
  # NixOS firewall, k3s and podman forwarding rules are untouched. Traffic
  # to the host itself (DHCP, DNS, the Ollama proxy) is input, not
  # forward, so it isn't affected.
  networking.nftables.tables.homelab-egress = {
    family = "inet";
    content = ''
      chain forward {
        type filter hook forward priority filter - 5; policy accept;
        iifname "incusbr0" ip saddr ${jrAddr} ct state established,related accept
        iifname "incusbr0" ip saddr ${jrAddr} drop
      }
    '';
  };
}
