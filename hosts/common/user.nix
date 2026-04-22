{ config, pkgs, ... }:
{
  users.users.vcaaron = {
    isNormalUser  = true;
    description   = "vcaaron";
    extraGroups   = [ "networkmanager" "wheel" "podman" ];
    packages      = with pkgs; [
      kdePackages.kate
    ];
  };

  users.groups.podman.name = "podman";


  security.sudo.extraRules = [
    {
      users = [ "vcaaron" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/podman";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
