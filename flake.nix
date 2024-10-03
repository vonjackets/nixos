{
  description = "A Nix-flake-based Python development environment";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils"; # Utility functions for Nix flakes
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, flake-utils }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs{
        inherit system;
      };

      pythonEnv = pkgs.buildEnv {
        name = "python-env";
        paths = with pkgs; [
          # -- Basic Required Files --
          bash # Basic bash to run bare essential code
          uutils-coreutils-noprefix # Essential GNU utilities (ls, cat, etc.)

          gzip # Compression utility
          tar

          # -- FISH! --
          fish
          fishPlugins.bass
          fishPlugins.bobthefish
          fishPlugins.foreign-env
          fishPlugins.grc
          

          # -- OpenSSL --
          cacert
          openssl
          openssl.dev

          # Compilers
          gcc
          grc
          glibc
          cmake
          gnumake
          
          # -- Development tools --
          python312
          python312Packages.pip
          pyenv
          poetry
          uv #python pkg manager

        
          # Misc. tools
          gnused
          which
          vim
          curl
          lsof
          strace
          ripgrep
          tree
          tree-sitter
          nix
          git
          eza
          bat
          ps
          ncurses
        ];

        # Path to the local fish config file
        fishConfig = pkgs.writeTextFile {
          name = "config.fish";
          destination = "/root/.config/fish/config.fish";
          text = builtins.readFile ./config.fish;
        };
      };

    in
    {
      packages.default = pkgs.dockerTools.buildImage {
        name = "python-dev";
        tag = "latest";
        copyToRoot = [pythonEnv];
        config = {
          WorkingDr = "/workspace";
          Env = [
            "SHELL=/bin/fish"
            "USER=root"
            "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
            "SSL_CERT_DIR=/etc/ssl/certs"
            "KUBE_EDITOR=nvim"
            
          ];
          Volumes = {};
          Cmd = ["/bin/fish"];
          extraCommands = ''
            # Create /tmp dir
            mkdir -p tmp
          '';
        };
      };
    }
  );
}