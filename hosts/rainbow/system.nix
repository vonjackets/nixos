{ config, lib, pkgs, ... }:
{
  networking.hostName = "rainbow";

  # Zen kernel: BORE scheduler + desktop-interactivity tuning. Worth it on
  # Zen 4 for mixed gaming + desktop workloads. nvidia-open builds against it.
  boot.kernelPackages = pkgs.linuxPackages_zen;

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

  # NVIDIA + Proton tuning. NVAPI unlocks DLSS Frame Generation under Proton,
  # which is the single biggest win for AAA at 7680x2160 on a 12 GB card.
  # 10 GB shader cache keeps the big games from re-compiling after updates.
  environment.sessionVariables = {
    __GL_SHADER_DISK_CACHE = "1";
    __GL_SHADER_DISK_CACHE_SIZE = "10737418240";
    PROTON_ENABLE_NVAPI = "1";
    PROTON_HIDE_NVIDIA_GPU = "0";
  };

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    environmentVariables = {
      CUDA_VISIBLE_DEVICES = "0";
      LD_LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudatoolkit}/lib64";
    };
  };
}
