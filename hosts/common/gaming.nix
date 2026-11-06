{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        inhibit_screensaver = 1;
      };
      cpu = {
        park_cores = "no";
        pin_cores = "no";
      };
      # NVIDIA: force max perf mode while a gamemode-wrapped process is running.
      # 1 = "Prefer Maximum Performance". Reverts when the process exits.
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        nv_powermizer_mode = 1;
      };
    };
  };

  hardware.xpadneo.enable = true;

  environment.systemPackages = with pkgs; [
    headsetcontrol # needed for logitech peripherals
    mangohud
    protonup-qt
    lutris
    mesa-demos
    nvtopPackages.nvidia
    discord-ptb # discord for chats with the homies not needed on other machines
  ];

  # enable invoking headsetcontrol w/o sudo
  services.udev.packages = [ pkgs.headsetcontrol ];
}
