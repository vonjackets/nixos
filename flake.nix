{
  description = "Define a basic set of packages and tools to support python software development";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix}:
    flake-utils.lib.eachDefaultSystem (system:
      let    
        pkgs = import nixpkgs { inherit system; };
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
        poetry
        uv
        
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

      #Write fish configuration for shell. TODO: Can we do better than this? How can we ensure we read directly from the repo, not the local system when this gets used?
      fishConfig = pkgs.writeText "config.fish" ''
## Set any proxies we might need here

if status is-interactive
    # Commands to run in interactive sessions can go here
end

function show_fish
    fish_logo
end

function filename_get_random --description="Sometimes you need a random name for a file and UUIDs suck"
    pwgen --capitalize --numerals --ambiguous 16 1
end

function files_compare --description="Requires two file paths to compare."
    if test $argv[1] = "" -o $argv[2] = ""
        echo "Arguments required for two files. Exiting."
        return 1
    end
    if test (sha512sum $argv[1] | cut -d ' ' -f 1) = (sha512sum $argv[2] | cut -d ' ' -f 1)
        return 0
    else
        return 1
    end
end

function files_compare_verbose --description="Text output for files_compare"
    if files_compare $argv[1] $argv[2]
        echo "Hashes match."
        return 0
    else
        echo "Hashes do not match."
        return 1
    end
end

#K8s kubctl admin helpers
function switch-context
    # Check if cluster name argument is provided
    if test -z $argv[1]
        echo "Usage: switch-context <cluster-name>"
        return 1
    end

    # Get the list of available contexts
    set contexts (kubectl config get-contexts -o name)

    # Check if the provided cluster name is valid
    if not contains $argv[1] $contexts
        echo "Error: Cluster '$argv[1]' not found"
        return 1
    end

    # Switch to the provided context
    kubectl config use-context $argv[1]

    echo "Switched to context: $argv[1]"
end

function switch_namespace
    set new_namespace $argv[1]

    # Check if the namespace is provided
    if test -z $new_namespace
        echo "Usage: switch_namespace <namespace>"
        return 1
    end

    # Check if kubectl is installed
    if not command -v kubectl > /dev/null
        echo "kubectl is not installed."
        return 1
    end

    # Get the current context
    set current_context (kubectl config current-context)

    # Check if the current context exists
    if test -z $current_context
        echo "No current context found. Please set up kubectl properly."
        return 1
    end

    # Set the namespace for the current context
    kubectl config set-context --current --namespace=$new_namespace

    if test $status -eq 0
        echo "Switched namespace to $new_namespace for context $current_context"
    else
        echo "Failed to switch namespace."
    end
end

function fish_prompt
    if set -q VIRTUAL_ENV
    echo -n -s (set_color -b blue white) "(" (basename "$VIRTUAL_ENV") ")" (set_color normal) " "
    end

    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end   
      '';
      ### End config
      in
      {
        paths = paths;
        fishConfig = fishConfig;
      }
    );
}
