# arch — Architect agent VM image.
#
# Built by the `arch-image-disk` / `arch-image-metadata` flake outputs via
# the upstream `incus-virtual-machine` module. Imported into Incus as a
# VM image; instances launched from it inherit this exact set of packages,
# users, and settings.
#
# Keep this file minimal. The Architect only writes to its task file;
# anything heavier belongs in eng-042's image when we add it.
{ pkgs, lib, ... }:
{
  # Image identity — overridden at `incus launch` time with the instance
  # name, but useful as a baseline so an uninitialized boot is still sane.
  networking.hostName = lib.mkDefault "arch";
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Guest-side Incus agent — runs the systemd service that lets
  # `incus exec` / `incus shell` reach into the VM. Without this, the
  # instance boots but Incus reports "VM agent isn't currently running".
  virtualisation.incus.agent.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "agent" ];
  };

  # Non-root user. T3 Code's browser sandbox doesn't work as root, and
  # running the agents under their own account keeps the blast radius
  # inside the VM small.
  users.users.agent = {
    isNormalUser = true;
    description = "Architect agent";
    extraGroups = [ "wheel" ];
    # Pin to 1000 so bind-mounted host directories (also uid 1000 under
    # vcaaron) are writable without idmap gymnastics. Auto-allocation
    # could have drifted to 1001+ if we ever add more users.
    uid = 1000;
    initialPassword = "agent";
  };
  security.sudo.wheelNeedsPassword = false;

  # Firewall is on. T3 listens on 3773 (default) and the pairing URL
  # points at the VM's bridge IP, so the client needs to reach that port.
  # The bridge has no external route — only rainbow and other VMs in the
  # `dev` project can reach this port — so opening it inside the VM
  # doesn't widen the external attack surface. T3's bearer still gates
  # anyone who makes it to the socket.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 3773 ];
  };

  services.openssh.enable = false;  # T3 is the only ingress path

  environment.systemPackages = with pkgs; [
    vim
    git
    jq
    # Persistent terminal panes for `t3 serve` + a working shell. Simpler
    # keybinds than tmux/screen; status bar lists them live.
    zellij
    # The agents themselves.
    t3code
    claude-code
  ];

  # Pin to the release the image is built against so NixOS doesn't try
  # a channel-style upgrade on first boot.
  system.stateVersion = "25.05";
}
