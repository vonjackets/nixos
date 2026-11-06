# nixos

Flake-based NixOS configuration for my fleet. This repo is both a landing pad
for rebuilding a machine from scratch and a playground for trying NixOS
features without losing them to `/etc/nixos` drift.

## Layout

```
flake.nix                 # inputs, overlays, per-host nixosConfigurations
hosts/
  common/                 # modules shared across every host
    system.nix            # bootloader, locale, SSH, PipeWire, Podman, Nix settings
    packages.nix          # baseline system packages
    user.nix              # vcaaron user + groups
    home.nix              # shared home-manager config
    unfree.nix            # allowed unfree packages
    gaming.nix            # Steam, gamescope, gamemode, MangoHud, controllers
    k3s.nix               # optional k3s module
    plasma.nix            # KDE Plasma config via plasma-manager
    programs/             # per-program dotfile modules (nushell, etc.)
  rainbow/                # main Linux dev + gaming desktop (AMD + NVIDIA Ada)
  scorpion/               # <see host dir>
  latitude/               # Dell laptop
  nix-builder/, nix-dev/  # build / dev sandboxes
AGENTS.md                 # rules for AI agents working in this repo
```

Each host directory contains at minimum:

- `hardware-configuration.nix` — generated, never hand-edited
- `system.nix` — NixOS modules for that host
- `home.nix` — host-specific home-manager layer (merged with `common/home.nix`)

Some hosts also carry a `STATUS.md` with a running list of improvements and
open questions for that machine.

## Flake inputs

- `nixpkgs` → `nixos-unstable`
- `home-manager`, `plasma-manager` (nix-community)
- `rust-overlay` (oxalica), `nixpkgs-mozilla`
- `claude-code` (sadjow/claude-code-nix)

All inputs are pinned via `flake.lock`. Bump with `nix flake update` — don't
do it as a drive-by.

## Rebuilding

The canonical entry point is `mask rebuild .#<host>`, which:

1. `git add -A` so untracked files become visible to Nix (flakes only see
   tracked files)
2. `sudo nixos-rebuild switch --flake "$FLAKE"`
3. prints the staged diff summary

`mask` is [jacobdeichert/mask](https://github.com/jacobdeichert/mask);
`maskfile.md` is a symlink to this README.

Examples:

```bash
mask rebuild .#rainbow
mask rebuild .#scorpion
mask rebuild .#latitude
```

Without `mask`:

```bash
sudo nixos-rebuild switch --flake .#rainbow
# or, to validate without activating:
nixos-rebuild build --flake .#rainbow
nixos-rebuild dry-activate --flake .#rainbow
```

## Adding a host

1. Create `hosts/<name>/` with `hardware-configuration.nix` (from
   `nixos-generate-config --dir ./hosts/<name>`) and a `system.nix`.
2. Add a `nixosConfigurations.<name>` block to `flake.nix` mirroring the
   existing ones.
3. `git add` the new files so the flake can see them.
4. `nixos-rebuild build --flake .#<name>` first; `switch` only once it builds
   cleanly.

## Conventions

- Host-local settings go in `hosts/<host>/`; anything placed under
  `hosts/common/` affects every machine.
- `hardware-configuration.nix` is generated output — do not edit by hand.
- Commits are short, imperative, lowercase. One concern per commit.
- See [AGENTS.md](./AGENTS.md) for the full set of rules (including security
  and secrets handling) that both humans and AI agents should follow when
  touching this repo.

## rebuild (FLAKE)
> Rebuild a host system using a given path, then prepare version control and view diffs.
> Example: `mask rebuild .#rainbow`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] running git add -A to make files visible to git and nix"
echo "DID YOU UPDATE .gitignore ?"
git add -A

echo "[2/3] nixos-rebuild switch"
sudo nixos-rebuild switch --flake "$FLAKE"

echo "[3/3] git diff (staged)"
git diff --cached --summary
```
