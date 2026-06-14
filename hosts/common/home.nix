{ config, pkgs, ... }:
let
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
      cp -r modules/kubernetes $out/
      cp -r modules/argx $out/kubernetes
      cp -r modules/lg $out/kubernetes
      cp -r modules/docker $out/
    '';
  };

in
{
  imports = [ ./plasma.nix ];

  home.username = "vcaaron";
  programs.home-manager.enable = true;

  programs.firefox = {
    enable = true;
    package = pkgs.firefox;
  };

  programs.zed-editor = {
    enable = true;
    extensions = [ "nix" "toml" "html" "python" "nu" ];
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
        light = "Gruvbox Light Soft";
        dark = "Monokai Charcoal (red)";
      };
      terminal.shell.program = "nu";
      load_direnv = "shell_hook";
      auto_update = false;
      lsp = {
        rust-analyzer.binary = {
          path_lookup = true;
        };
        nix.binary.path_lookup = true;
      };
    };
  };

  programs.nushell = {
    enable = true;
    configFile.source = ./programs/nushell/config.nu;
  };

  home.file.".config/nushell/modules" = {
    source = nuScriptsSubset;
  };
  # arbitrarilly set up env for cargo
  home.file.".cargo/config.toml" = {
    text = ''
      [env]
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig"
    '';
    force = true;
  };
  home.file.".config/zed/themes/monokai-charcoal.json".source = ./programs/zed/themes/monokai-charcoal.json;
  home.file.".config/git/config".source = ./programs/.gitconfig;
  home.file.".config/starship/starship.toml".source = ./programs/starship.toml;
  home.file.".config/ghostty/config" = {
    source = ./programs/ghostty.config;
    force = true;
  };
  home.sessionVariables = {
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    };
  home.stateVersion = "25.05";
}
