
{
  description = "My NixOS configuration (flake-based)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Add other inputs later (home-manager, hardware, etc.)
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # proper firefox overlay
    nixpkgs-mozilla.url = github:mozilla/nixpkgs-mozilla;
    # sadjow's claude code vs nixpkgs
    # We'll evaluate to see how much we like it.
    claude-code.url = "github:sadjow/claude-code-nix";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };
  outputs = { self, nixpkgs, home-manager, nixpkgs-mozilla, claude-code, rust-overlay, ... }:
  {
    nixosConfigurations.scorpion = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        # Core system config
        ./modules/system.nix
        ./modules/unfree.nix

        # Overlays belong here
        {
          nixpkgs.overlays = [
            rust-overlay.overlays.default
            claude-code.overlays.default
            nixpkgs-mozilla.overlay
          ];
        }

        # Home Manager
        home-manager.nixosModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.useGlobalPkgs = true;
          home-manager.users.vcaaron = import ./modules/home.nix;
        }
      ];
    };
  };
}
