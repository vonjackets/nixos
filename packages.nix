# Define packages intended for use in the a typical developer environment
#
let
    pkgs = import <nixpkgs> {};
    paths = with pkgs; [
        # -- Basic Required Files --
        bashInteractiveFHS 
        uutils-coreutils-noprefix # Essential GNU utilities (ls, cat, etc.)

        gzip # Compression utility
        gnutar

        # -- FISH! --
        fish

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
    
    #read configurations
    fishConfig = builtins.readFile ./fish/config.fish;
# Return the list of packages
in 
{
    paths
    fishConfig
}
