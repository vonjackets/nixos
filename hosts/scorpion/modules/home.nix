
{ config, pkgs, ... }:

{
  home.username = "vcaaron"; # must match system user

  programs.home-manager.enable = true;


  # example: Firefox
  programs.firefox.enable = true;

  # dotfile symlinks
  home.file.".config/git/config".source = ./programs/.gitconfig;
  home.file.".config/nushell/config.nu".source = ./programs/nushell/config.nu;
  # TODO: I don't keep an env.nu file, but if I did...
  # home.file.".config/nushell/env.nu".source    = ./programs/nushell/env.nu;

  home.stateVersion = "25.05";
}
