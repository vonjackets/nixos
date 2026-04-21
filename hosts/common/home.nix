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
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;
  };

  programs.zed-editor = {
    enable = true;
    extensions = [ "nix" "toml" "html" "python" ];
    userSettings = {
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      vim_mode = true;
      ui_font_size = 16;
      buffer_font_size = 16;
      theme = {
        mode = "system";
        light = "Monokai Night";
        dark = "One Dark";
      };
      terminal = {
        shell = {
          program = "nu";
        };
      };
      load_direnv = "shell_hook";
      auto_update = false;
      lsp = {
        rust-analyzer = {
          binary = {
            path_lookup = true;
          };
        };
        nix = {
          binary = {
            path_lookup = true;
          };
        };
      };
    };
  };

  # Add our desired theem
  home.file.".config/zed/themes/monokai-charcoal.json".source = ./programs/zed/themes/monokai-charcoal.json;
  # dotfile symlinks
  home.file.".config/git/config".source = ./programs/.gitconfig;
  # setup nushell stuff
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
