{ config, pkgs, ... }:
let
  auxDataDirectory = "/main";
in
{
  networking.hostName = "scorpion";

  # scorpion has a bluetooth adapter, latitude does not
  hardware.bluetooth.enable = true;

  # Spotify local network discovery
  networking.firewall.allowedTCPPorts = [ 57621 ];

  # redirect podman storage to HDD
  virtualisation.containers.storage.settings.storage = {
    driver    = "overlay";
    graphroot = "${auxDataDirectory}/podman/storage";
    runroot   = "${auxDataDirectory}/podman/run";
  };

  systemd.tmpfiles.rules = [
    "d ${auxDataDirectory}/podman         0755 root root -"
    "d ${auxDataDirectory}/podman/storage 0755 root root -"
    "d ${auxDataDirectory}/podman/tmp     1777 root root -"
    "d ${auxDataDirectory}/podman/run     1777 root root -"
  ];

  # scorpion-specific packages — gaming, media, office
  environment.systemPackages = with pkgs; [
    spotify
    libreoffice-qt
    hunspell
    hunspellDicts.uk_UA
    hunspellDicts.th_TH
    hyphenDicts.en_US
    claude-code
  ];
}
