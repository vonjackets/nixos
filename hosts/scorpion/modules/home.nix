
{ config, pkgs, ... }:

{
  home.username = "vcaaron"; # must match system user

  programs.home-manager.enable = true;


  # example: Firefox
  programs.firefox.enable = true;

  # dotfile symlinks
  home.file.".config/git/config".source = ./programs/.gitconfig;
  # setup nushell stuff
  # TODO: I REALLY REALLY want those goddman nushell scripts with all the helpers and aliases,
  # reinventing the wheel sucks
  # We should just fetch them all (or at least the ones we want) from the github directly and add them here figure out how.
  home.file.".config/nushell/config.nu" = {
    source = ./programs/nushell/config.nu;
    force = true; #clobber whatevers there
  };

  home.file.".config/ghostty/config" = {
    source = ./programs/ghostty.config;
    force = true;
  };

  # TODO: We should configure zed here
  # TODO: I don't keep an env.nu file, but if I did...
  # home.file.".config/nushell/env.nu".source    = ./programs/nushell/env.nu;

  home.stateVersion = "25.05";
}
