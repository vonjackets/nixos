
# modules/unfree.nix
# unfortunate but necessary, we can't get everything for free (yet)
{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
}
