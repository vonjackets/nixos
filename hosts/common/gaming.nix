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
      # Free the 4070's 12 GB for the game by stopping Ollama while a game
      # runs; restart it after. Relies on the polkit rule below allowing the
      # gaming user to manage ollama.service without a password prompt.
      custom = {
        start = "${pkgs.systemd}/bin/systemctl stop ollama.service";
        end = "${pkgs.systemd}/bin/systemctl start ollama.service";
      };
    };
  };

  # Let non-root users manage ollama.service so the gamemode start/end hooks
  # above don't need sudo. Scoped to this one unit.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "ollama.service" &&
          subject.isInGroup("users")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Lower PipeWire quantum for competitive audio. 512 default / 32 min gives
  # ~10 ms round-trip on this hardware; keeps headroom for voice chat.
  services.pipewire.extraConfig.pipewire."92-low-latency" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 512;
      "default.clock.min-quantum" = 32;
      "default.clock.max-quantum" = 2048;
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
