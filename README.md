# NixOS

Welcome, this repo is meant to serve as my landing pad for when I inevitably need to flatten and rebuild a machine.
It's mean to be both that and a playground for trying out some nixos stuff.

If you have [mask](https://github.com/jacobdeichert/mask) installed, you can use it to quickly perform these common operations.
If not, consider installing it to further oxidize your life.

For example, from here in the root of the project, try running `mask build agents` to quickly build the cargo workspace with nix.
this will give you all the binaries we have defined for the project.


## rebuild (FLAKE)
  > Rebuild the system using a given path, then prepare version control and view diffs
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] nixos-rebuild switch"
sudo nixos-rebuild switch --flake "$FLAKE"

echo "[2/3] git add"
git add -A

echo "[3/3] git diff (staged)"
git diff --cached --summary

```
---
