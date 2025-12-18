{
  pkgs
};
# Define packages intended for use in the a typical developer environment
# These will be shared across hosts as a common baseline set. Each host might add their own to this list, downstream.
let
    systemPkgs = with pkgs; [
      # -- Basic Required Files --
     gnugrep # GNU version of grep for searching text
     gnused # GNU version of sed for text processing
     gnutar # GNU version of tar for archiving
     gzip # Compression utility


     ghostty # a simply better terminal
     nushell # a simply better shell
     vim # THE editor of editors
     zed-editor # because we actually code
     starship
     atuin

     mask # a pretty good comamnd runner
     # -- OpenSSL --
     cacert
     dropbear
     openssh
     openssl
     openssl.dev

     # -- Development tools --
     podman-tui # status of containers in the terminal
     docker-compose # starts group of containers for dev
     zoxide # better than cd
     minikube # local k8s testing
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
     gnugrep
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

     # dhall - actually good configuration
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
    ];
in
{
    inherit systemPkgs;
}
