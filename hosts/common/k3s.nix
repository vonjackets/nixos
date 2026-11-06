# a separate, optional module that gets explicitly imported by the hosts that want it, not baked into sharedModules.
# The reason isn't philosophical purity, it's resource footprint: services.k3s.enable = true doesn't add a binary to PATH,
#  it starts a systemd unit running an apiserver, controller-manager, scheduler, kubelet, containerd, flannel, and CoreDNS — a genuinely non-trivial always-on process tree.
# That's fine on rainbow, where you have CPU/RAM to spare and it's exactly the kind of dev tooling the machine exists for.
{ ... }:
{
  # The k3s API (6443) is deliberately NOT opened on the firewall: this is a
  # single-node cluster driven from this machine (kubectl hits 127.0.0.1),
  # and pods reach the apiserver over the trusted CNI interfaces below.
  # Open it host-locally only if another machine needs to join or manage it.

  # NixOS's firewall drops forwarded traffic on flannel's CNI interfaces by
  # default, which breaks pod-to-pod and pod-to-apiserver networking before
  # you even get to writing a manifest. Trust them outright for a
  # single-node local cluster.
  networking.firewall.trustedInterfaces = [ "cni0" "flannel.1" ];

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      ''--write-kubeconfig-mode "0644"''
    ];
  };

  environment.variables = {
    KUBECONFIG="etc/rancher/k3s/k3s.yaml";
  };
}
