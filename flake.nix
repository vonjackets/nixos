{
  description = "A Nix flake that builds a basic environment containing essential tools for software development, intended to be used in shells, devcontainers, etc.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils"; # Utility functions for Nix flakes
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, flake-utils, systems }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs{
        inherit system;
      };
    in 
    {
      packages.default = pkgs.buildEnv {
        name = "devenv";
        #Define "system level" packages
        paths = with pkgs; [
          # -- Basic Required Files --
          bashInteractiveFHS 
          uutils-coreutils-noprefix # Essential GNU utilities (ls, cat, etc.)

          gzip # Compression utility
          gnutar

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