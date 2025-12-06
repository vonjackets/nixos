
{
  description = "My NixOS configuration (flake-based)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Add other inputs later (home-manager, hardware, etc.)
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        scorpion = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/system.nix
            # Inje`t Home Manager as a NixOS module
            home-manager.nixosModules.home-manager
            # Wire home.nix
            {
                home-manager.useUserPackages = true;
                home-manager.useGlobalPkgs = true;

                home-manager.users.vcaaron = import ./modules/home.nix;
            }
          ];
        };
      };
    };
}
