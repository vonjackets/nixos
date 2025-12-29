
{
  description = "My NixOS configuration (flake-based)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Add other inputs later (home-manager, hardware, etc.)
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # proper firefox overlay
    nixpkgs-mozilla.url = github:mozilla/nixpkgs-mozilla;

  };

  outputs = { self, nixpkgs, home-manager, nixpkgs-mozilla, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ nixpkgs-mozilla.overlay ]; };
    in {
      nixosConfigurations = {
        scorpion = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/system.nix
            ./modules/unfree.nix
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
