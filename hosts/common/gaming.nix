{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  programs.gamemode.enable = true;

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
