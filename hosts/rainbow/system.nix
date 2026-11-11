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
  services.tailscale.enable = true;
  networking.nftables.enable = true;

  networking.firewall = {
    enable = true;
    # Always allow traffic from your Tailscale network
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
    # Allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  # 2. Force tailscaled to use nftables (Critical for clean nftables-only systems)
  # This avoids the "iptables-compat" translation layer issues.
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  # 3. Optimization: Prevent systemd from waiting for network online
  # (Optional but recommended for faster boot with VPNs)
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;

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
    ../common/incus.nix
    ./homelab.nix
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
    # Agent-harness control surface for the homelab plan (see HOMELAB.md).
    # Installed on the host so the CLI is here for pairing + triage; each
    # agent instance will install its own t3 inside the VM.
    t3code
    # btop with the NVIDIA driver on its runpath, so its GPU box shows the
    # 4070 (plain btop can't find libnvidia-ml). No CUDA toolkit involved.
    # hiPrio: it wins over the plain btop from common/packages.nix.
    (lib.hiPrio btop-cuda)
  ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # ollama-cuda ships its own libcudart/libcublas next to its runners and
    # finds them via RUNPATH. Don't set LD_LIBRARY_PATH to cudatoolkit: it
    # shadows the bundled libs and drags ~3.2 GiB of CUDA into the closure.
    environmentVariables = {
      CUDA_VISIBLE_DEVICES = "0";
      # Ollama's default is 4096, too small for an agent harness (OpenCode's
      # system prompt + tools alone use much of it). 32k measured at ~11.4 GB
      # total VRAM with gemma4:12b fully on GPU and the desktop running.
      OLLAMA_CONTEXT_LENGTH = "32768";
    };
  };
}
