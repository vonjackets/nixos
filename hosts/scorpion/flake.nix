
{
  description = "My NixOS configuration (flake-based)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Add other inputs later (home-manager, hardware, etc.)
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        scorpion = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./system.nix
          ];
        };
      };
    };
}
