{
  pkgs,
}:
let
in
{
  systemPackages = with pkgs; [
    # -- Basic Required Files --
    bash # Basic bash to run bare essential code
    glibcLocalesUtf8
    uutils-coreutils-noprefix # Essential GNU utilities (ls, cat, etc.)
    gnugrep # GNU version of grep for searching text
    gnused # GNU version of sed for text processing
    gnutar # GNU version of tar for archiving
    gzip # Compression utility

    # -- Nix, of course --
    nix
    # -- FISH! --
    figlet
    fish
    fishPlugins.bass
    fishPlugins.bobthefish
    fishPlugins.foreign-env
    fishPlugins.grc
    cowsay
    starship
    atuin

    # -- OpenSSL --
    cacert
    dropbear
    openssh
    openssl
    openssl.dev

    # -- Misc. Tools --
    bat
    curl
    delta
    direnv
    eza
    fd
    findutils
    fzf
    gawk
    getent
    git
    gnugrep
    iproute2
    jq
    lsof
    man
    man-db
    man-pages
    man-pages-posix
    ncurses
    procps
    ps
    ripgrep
    rsync
    strace
    tree
    tree-sitter
    which

    dhall
    dhall-yaml
    dhall-json

    # -- Compilers, Etc. --
    # cmake
    # gnumake
    # # clang or clang-tools are not strictly needed if stdenv is clang-based
    # # but you can add them if you want the standalone `clang` CLI, e.g.:
    # pkgs.llvmPackages_19.clang
    # #pkgs.llvmPackages_19.clang-unwrapped
    # pkgs.llvmPackages_19.lld
    # glibc
    # clangLldWrapper

    # -- Rust --
    # (lib.meta.hiPrio (rust-bin.nightly.latest.default.override {
    #   extensions = [ "rust-src" "rust-analyzer" ];
    #   targets = [ "wasm32-unknown-unknown" ];
    # }))

    pkg-config
    util-linux

    # # The last editor you'll ever use
    # zed

    # Put any extra packages or libraries you need here. For example,
    # if working on a Rust project that requires a linear algebra
    # package:
    # openblas

  ];

}
