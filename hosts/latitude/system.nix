{ config, pkgs, ... }:
{

  networking.hostName = "latitude";

  hardware.bluetooth.enable = true;

  # Dell-specific hardware
  services.thermald.enable = true;  # Intel thermal management, worth enabling on Latitude
  services.fwupd.enable = true;     # firmware updates, Dell supports this well via LVFS

}
