# Shared by the Blitz lane VMs (eng, sec, test): keep the lane's Nix
# environment alive across GCs and re-rolls.
#
# The Nix store lives on the VM's root disk, which a re-roll replaces, while
# GC roots live on the persistent home volume. So after every re-roll the
# Blitz `ci` shell (~5 GiB) and the ACE flake input are gone. ACE can't be
# refetched in a VM: Blitz's flake pins it over SSH to a server the VMs
# can't reach. `blitz-roots` re-seeds ACE from the VM's local clone at the
# pinned rev, and roots both (HOMELAB.md "Housekeeping", GC roots). It runs
# at boot, and by hand after the lane bumps the shell or ACE's pin.
{ pkgs, ... }:
let
  blitz-roots = pkgs.writeShellApplication {
    name = "blitz-roots";
    runtimeInputs = with pkgs; [ git jq gnugrep coreutils ];
    text = builtins.readFile ./blitz-roots.sh;
  };
in
{
  environment.systemPackages = [ blitz-roots ];

  systemd.services.blitz-roots = {
    description = "Root the Blitz ci shell and ACE input for this lane";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "agent-home.service" "incus-agent.service" ];
    wants = [ "network-online.target" ];
    requires = [ "agent-home.service" ];
    # Nix itself must be on PATH for the agent user's nix commands.
    path = [ "/run/current-system/sw" ];
    serviceConfig = {
      Type = "oneshot";
      User = "agent";
      Group = "users";
      Environment = "HOME=/home/agent";
      ExecStart = "${blitz-roots}/bin/blitz-roots";
      # A first fetch of the shell takes minutes; don't hold up boot.
      TimeoutStartSec = "1h";
    };
    # Without a lane clone or the ACE clone there's nothing to root.
    unitConfig.ConditionPathExists = [ "/work/flake.nix" "/home/agent/projects/ACE/.git" ];
  };
}
