
# Root the Blitz ci shell and the ACE flake input for this lane VM.
# ACE is pinned over SSH (unreachable from VMs), so seed it from the local clone.

cd /work
mkdir -p ~/.local/state/nix/profiles
R=$(grep -o 'ACE.git?rev=[0-9a-f]*' flake.nix | cut -d= -f2)
git -C ~/projects/ACE cat-file -e "$R^{commit}" 2>/dev/null || git -C ~/projects/ACE fetch -q origin
P=$(nix flake archive --json path:/work \
      --override-input ace "git+file:///home/agent/projects/ACE?rev=$R" | jq -r .inputs.ace.path)
nix-store --realise "$P" --add-root ~/.local/state/nix/profiles/ace-src >/dev/null
nix develop --profile ~/.local/state/nix/profiles/blitz-ci "path:/work#ci" --command sh -c 'command -v cargo'
