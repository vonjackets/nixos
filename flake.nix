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

  outputs = { self, nixpkgs, home-manager, nixpkgs-mozilla, claude-code, rust-overlay, plasma-manager, ... }:
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
        # When HM wants to write a file that already exists on disk (e.g. a
        # stale fontconfig conf from a previous activation), move the old copy
        # aside with this suffix instead of failing the switch.
        home-manager.backupFileExtension = "backup";
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

    # Agent VM images, one per homelab role (see hosts/rainbow/HOMELAB.md),
    # built via the upstreamed `incus-virtual-machine` module in nixpkgs.
    # That module pulls in the qcow2 builder, the qemu-guest profile, and
    # the Incus metadata tarball generator. Each role imports
    # hosts/common/agent-vm.nix (incus-agent, `agent` user, t3-serve).
    #
    # Build and import, e.g. for `eng`:
    #   DISK=$(nix build --no-link --print-out-paths .#eng-image-disk)
    #   META=$(nix build --no-link --print-out-paths .#eng-image-metadata)
    #   incus image import "$META"/tarball/*.tar.xz "$DISK"/*.qcow2 \
    #     --alias eng-vm --project dev
    packages.x86_64-linux =
      let
        lib = nixpkgs.lib;
        mkAgent = role:
          lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./hosts/rainbow/agents/${role}/configuration.nix
              {
                nixpkgs.overlays = sharedOverlays;
                # claude-code and friends are unfree; let the image build.
                nixpkgs.config.allowUnfree = true;
              }
              "${nixpkgs}/nixos/modules/virtualisation/incus-virtual-machine.nix"
            ];
          };
        roles = [ "eng" "sec" "doc" "jr" ];
      in
        lib.foldl' (acc: role:
          let sys = mkAgent role; in
          acc // {
            "${role}-image-disk" = sys.config.system.build.qemuImage;
            "${role}-image-metadata" = sys.config.system.build.metadata;
          }) { } roles;
  };
}
