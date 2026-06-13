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
    mangohud
    protonup-qt
    lutris
    mesa-demos          # glxinfo, glxgears - useful for exactly this kind of driver sanity check
    nvtopPackages.nvidia
    discord-ptb # discord for chats with the homies not needed on other machines
  ];
}
