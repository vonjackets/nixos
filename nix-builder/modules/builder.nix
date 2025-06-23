{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  system.stateVersion = "24.05";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/xvda";

  time.timeZone = "UTC";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 5000 ]; # Add 5000 for nix-serve-ng if needed
  };

  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
    passwordAuthentication = false;
    openFirewall = true;
  };

  virtualisation.docker.enable = true;

  users.users.runner = {
    isNormalUser = true;
    home = "/home/runner";
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [ /* your SSH key here */ ];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  environment.variables = {
    EDITOR = "vim";
    PAGER = "less";
  };

  nix.settings = {
    trusted-users = [ "root" "runner" ];
    substituters = [
      "https://cache.nixos.org"
      "http://builder.internal:5000" # Replace with your cache endpoint
    ];
    trusted-public-keys = [
      "mycache-1:abcd1234..."
    ];
    experimental-features = [ "nix-command" "flakes" ];
  };

  # configure the cache to be available via nix-serve
  services.nix-serve = {
    enable = true;
    secretKeyFile = "/etc/nix/cache-priv-key.pem";
  };

  environment.etc."nix/cache-priv-key.pem".source = ./secrets/cache-priv-key.pem;
}
