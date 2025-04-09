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

function nix-update-remote
    set -l dns_name $argv[1]

    if test -z "$dns_name"
        echo "Usage: nix-update-remote <ec2-public-dns>"
        return 1
    end

    # Resolve the IP from DNS
    set -l ip (dig +short $dns_name | head -n 1)

    if test -z "$ip"
        echo "Failed to resolve IP from DNS: $dns_name"
        return 1
    end

    echo "Resolved IP: $ip"

    set -l alias nix-ec2
    set -l ssh_key ~/.ssh/nix-remote

    # Clean up known_hosts entries
    echo "Cleaning up old SSH known_hosts entries..."
    ssh-keygen -R $dns_name > /dev/null
    ssh-keygen -R $ip > /dev/null

    # Update ~/.ssh/config
    echo "Updating SSH config entry for '$alias'..."
    mkdir -p ~/.ssh
    grep -v "Host $alias" ~/.ssh/config 2>/dev/null | grep -v "HostName" > ~/.ssh/config.new

    echo "
Host $alias
    HostName $dns_name
    User root
    IdentityFile $ssh_key
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts
" >> ~/.ssh/config.new

    mv ~/.ssh/config.new ~/.ssh/config
    chmod 600 ~/.ssh/config

    # Copy SSH key + config to root (for nix-daemon)
    echo "Copying SSH key and config to root..."
    sudo mkdir -p /var/root/.ssh
    sudo cp ~/.ssh/config /var/root/.ssh/config
    sudo cp $ssh_key /var/root/.ssh/
    sudo cp $ssh_key.pub /var/root/.ssh/
    sudo chmod 600 /var/root/.ssh/config /var/root/.ssh/nix-remote
    sudo chmod 644 /var/root/.ssh/nix-remote.pub

    # Confirm root can connect
    echo "Testing root ssh connection to $alias..."
    sudo ssh -o StrictHostKeyChecking=accept-new $alias "echo Connection successful from root"

    echo "✅ Remote builder '$alias' is ready for use in Nix builds."
end

