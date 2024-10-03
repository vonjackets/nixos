{
  description = "A Nix-flake-based development environment";

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
    in 
    {
      default = pkgs.buildEnv {
        name = "devenv";
        #Define "system level" packages
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
      };
    }
  );
}