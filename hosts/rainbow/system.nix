{ config, lib, pkgs, ... }:
{
  networking.hostName = "rainbow";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;                 # Ada Lovelace supports open kernel modules
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaSettings = true;
    powerManagement.enable = false;  # desktop, no suspend/resume GPU power-state dance needed
  };

  imports = [
    ../common/gaming.nix
  ];
}
