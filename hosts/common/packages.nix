{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # -- Basic Required Files --
    gnugrep
    gnused
    gnutar
    gzip
    ghostty
    nushell
    vim
    zed-editor
    starship
    atuin
    mask
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
    rustlings
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
    glibc
    grc
    pkg-config
    util-linux
    sops
    envsubst
    # -- Podman / container runtime deps --
    slirp4netns
    fuse-overlayfs
  ];
}
