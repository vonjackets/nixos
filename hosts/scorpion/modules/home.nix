
{ config, pkgs, ... }:
let
  # go get some comunity modules I like
  nuScriptsSubset = pkgs.stdenv.mkDerivation {
    name = "nu-scripts-subset";

    src = builtins.fetchGit {
      url = "https://github.com/nushell/nu_scripts.git";
      name = "nu_scripts";
      rev = "485a62c9a3522ef13abb1770523a2a566da721bd";
      ref = "HEAD";
    };
    installPhase = ''
      mkdir -p $out

      cp -r modules/argx $out/

      # explicitly cp argx to the k8s module, because it'll break otherwise and fail to find it
      cp -r modules/kubernetes $out/
      cp -r modules/argx $out/kubernetes
      cp -r modules/lg $out/kubernetes
      cp -r modules/weather $out/
      cp -r modules/docker $out/
    '';
};
in
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

  home.file.".config/nushell/modules" = {
    source = nuScriptsSubset;
    # recursive = true;
  };
  home.file.".config/starship/starship.toml".source = ./programs/starship.toml;

  home.file.".config/ghostty/config" = {
    source = ./programs/ghostty.config;
    force = true;
  };



  home.packages = [
    pkgs.signal-desktop
  ];
  # TODO: We should configure zed here
  # TODO: I don't keep an env.nu file, but if I did...
  # home.file.".config/nushell/env.nu".source    = ./programs/nushell/env.nu;

  home.stateVersion = "25.05";
}
