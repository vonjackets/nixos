{
  description = "My NixOS configuration (flake-based)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-mozilla.url = "github:mozilla/nixpkgs-mozilla";
    claude-code.url = "github:sadjow/claude-code-nix";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixpkgs-mozilla, claude-code, rust-overlay, plasma-manager , ... }:
  let
    sharedOverlays = [
      rust-overlay.overlays.default
      claude-code.overlays.default
      nixpkgs-mozilla.overlay
    ];
    sharedModules = [
      ./hosts/common/system.nix
      ./hosts/common/packages.nix
      ./hosts/common/user.nix
      ./hosts/common/unfree.nix
      { nixpkgs.overlays = sharedOverlays; }
      home-manager.nixosModules.home-manager
      {
        home-manager.useUserPackages = true;
        home-manager.useGlobalPkgs = true;
        home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ]; # renamed
      }
    ];
  in
  {
    nixosConfigurations.rainbow = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = sharedModules ++ [
        ./hosts/rainbow/hardware-configuration.nix
        ./hosts/rainbow/system.nix
        {
          home-manager.users.vcaaron = {
            imports = [
              ./hosts/common/home.nix
              ./hosts/rainbow/home.nix
            ];
          };
        }
      ];
    };
    nixosConfigurations.scorpion = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = sharedModules ++ [
        ./hosts/scorpion/hardware-configuration.nix
        ./hosts/scorpion/system.nix
        {
          home-manager.users.vcaaron = {
            imports = [
              ./hosts/common/home.nix
              ./hosts/scorpion/home.nix
            ];
          };
        }
      ];
    };
    nixosConfigurations.latitude = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = sharedModules ++ [
        ./hosts/latitude/hardware-configuration.nix
        ./hosts/latitude/system.nix
        {
          home-manager.users.vcaaron = {
            imports = [
              ./hosts/common/home.nix
              ./hosts/scorpion/home.nix
            ];
          };
        }
      ];
    };
  };
}
