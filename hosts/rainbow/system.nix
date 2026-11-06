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
  # LIBVA_DRIVER_NAME points VA-API clients (Firefox, mpv, OBS) at the
  # NVIDIA-nvdec backend so HW video decode doesn't burn CPU during games.
  environment.sessionVariables = {
    __GL_SHADER_DISK_CACHE = "1";
    __GL_SHADER_DISK_CACHE_SIZE = "10737418240";
    PROTON_ENABLE_NVAPI = "1";
    PROTON_HIDE_NVIDIA_GPU = "0";
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    # KWin: delay VRR cursor updates to hide the NVIDIA + Plasma 6 right-edge
    # taskbar flicker on wide VRR panels (Neo G9 57" symptom).
    KWIN_DRM_DELAY_VRR_CURSOR_UPDATES = "1";
  };

  # Enable the NVIDIA VA-API shim so Firefox/Chromium/mpv can HW-decode via
  # NVDEC. Needs enable32Bit for Steam-side consumers of libva.
  hardware.graphics.extraPackages = with pkgs; [ nvidia-vaapi-driver ];

  # Gaming-oriented kernel tuning.
  #   swappiness=10   : prefer keeping game pages resident over swapping them.
  #   vfs_cache_pressure=50 : hold inode/dentry cache longer (faster asset loads).
  #   dirty_ratio/background : smaller to avoid big writeback stalls mid-frame.
  #   net.*                : larger buffers for high-bandwidth online play + streaming.
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    "net.core.netdev_max_backlog" = 5000;
  };

  # zram-backed compressed swap. On a 32 GB box running Ollama + k3s + a game,
  # shader-compile spikes can still pressure RAM; zstd-compressed zram is an
  # order of magnitude faster than the on-disk swap partition.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  environment.systemPackages = with pkgs; [
    claude-code
  ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    environmentVariables = {
      CUDA_VISIBLE_DEVICES = "0";
      LD_LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudatoolkit}/lib64";
    };
  };
}
