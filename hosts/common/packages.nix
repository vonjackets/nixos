{ pkgs, ... }:
let

rustToolchain = pkgs.rust-bin.stable.latest.default.override {
  extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
};

in
{
  environment.systemPackages = with pkgs; [

    # -- Basic Required Files --
    gnugrep
    gnused
    gnutar
    gzip
    ghostty
    nushell
    nufmt
    nu-lint
    vim
    zed-editor
    starship
    atuin
    mask
    just
    # -- OpenSSL --
    cacert
    dropbear
    openssh
    openssl
    openssl.dev
    # -- Development tools --
    podman-tui
    docker-compose
    zoxide
    minikube
    k9s
    kubectl
    fluxcd
    bat
    curl
    xh
    delta
    direnv
    eza
    fd
    findutils
    fzf
    gawk
    getent
    git
    iproute2
    jq
    yq
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
    # -- Dhall --
    dhall
    dhall-yaml
    dhall-json
    dhall-lsp-server
    # -- Compilers, Etc. --
    cmake
    gnumake
    gcc
    glibc
    grc
    pkg-config
    util-linux
    sops
    envsubst
    rustToolchain
    # -- Podman / container runtime deps --
    slirp4netns
    fuse-overlayfs
    spotify
    # office tools
    libreoffice-qt
    hunspell
    hunspellDicts.uk_UA
    hunspellDicts.th_TH
    hyphenDicts.en_US

    signal-desktop
  ];
}
