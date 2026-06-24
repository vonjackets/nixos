{ config, lib, pkgs, ... }:
{
  networking.hostName = "rainbow";


  hardware.bluetooth.enable = true;
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
    powerManagement.enable = true; # prevent wayland and the plasma compisitor from crashing
  };

  # Rainbow is a desktop, and sometimes we leave it for extended periods, no real point in letting it sleep since power is consistent
  systemd.sleep.settings.Sleep = {

    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # modules from ../common that we might want for extra functionality
  imports = [
    ../common/gaming.nix
    ../common/k3s.nix
  ];
}
