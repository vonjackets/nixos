# a separate, optional module that gets explicitly imported by the hosts that want it, not baked into sharedModules.
# The reason isn't philosophical purity, it's resource footprint: services.k3s.enable = true doesn't add a binary to PATH,
#  it starts a systemd unit running an apiserver, controller-manager, scheduler, kubelet, containerd, flannel, and CoreDNS — a genuinely non-trivial always-on process tree.
# That's fine on rainbow, where you have CPU/RAM to spare and it's exactly the kind of dev tooling the machine exists for.
{ ... }:
{
  networking.firewall.allowedTCPPorts = [
    6443 # k3s API server
  ];

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
