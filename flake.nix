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

  outputs = { self, nixpkgs, home-manager, nixpkgs-mozilla, claude-code, rust-overlay, plasma-manager ,.. }:
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
        home-manager.users.vcaaron = import ./hosts/common/home.nix;
        home-manager.sharedModules = [ plasma-manager.homeManagerModules.plasma-manager ];
      }
    ];
  in
  {
    nixosConfigurations.scorpion = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = sharedModules ++ [
        ./hosts/scorpion/hardware-configuration.nix
        ./hosts/scorpion/system.nix
      ];
    };

    nixosConfigurations.latitude = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = sharedModules ++ [
        ./hosts/latitude/hardware-configuration.nix
        ./hosts/latitude/system.nix
      ];
    };

    devShells.x86_64-linux.rustStable = let
       system = "x86_64-linux";
       pkgs = import nixpkgs {
         inherit system;
         overlays = [
           rust-overlay.overlays.default
           claude-code.overlays.default
           nixpkgs-mozilla.overlay
         ];
       };

       # Grab a pinned “stable” toolchain from rust-overlay
       rustToolchain = pkgs.rust-bin.stable.latest.default.override {
         # if you want specific components, add them here
         extensions = [ "rust-src" ];
       };

       # Clang + LLD wrapper so Rust linking works
       rustSysroot = "/usr";
       clangLldWrapper = pkgs.writeShellScriptBin "clang-lld-wrapper" ''
         exec ${pkgs.llvmPackages_19.clang}/bin/clang \
           -fuse-ld=lld \
           --sysroot=${rustSysroot} \
           "$@"
       '';
     in pkgs.mkShell {
       name = "rust-stable-shell";
       buildInputs = with pkgs; [
         rustToolchain
         rust-analyzer
         clangLldWrapper
         pkgs.llvmPackages_19.lld
         pkgs.llvmPackages_19.clang
         cmake
         gnumake
       ];

       # Environment vars for Rust and linker
       RUSTC_LINKER = "clang-lld-wrapper";
       CC = "clang-lld-wrapper";
       CXX = "clang++";
       PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig";
       RUSTFLAGS="-Clinker=clang-lld-wrapper";

       shellHook = ''
         # Set up RUST_SRC_PATH so tools like rust-analyzer work
         export RUST_SRC_PATH=${rustToolchain}/lib/rustlib/src/rust/library
         export NU_CONFIG_DIR=$PWD/modules/programs/nushell

         # Optional: create config if missing
         mkdir -p $NU_CONFIG_DIR
         if [ ! -f $NU_CONFIG_DIR/config.nu ]; then
           echo '$env.PROMPT_COMMAND = {|| "⚡ "}' > $NU_CONFIG_DIR/config.nu
         fi

         # Avoid infinite recursion if the shell is launched from within devShell
         if [ -z "$IN_NIX_NU" ]; then
           export IN_NIX_NU=1
           exec nu --config $NU_CONFIG_DIR/config.nu
         fi

       '';
     };
  };
}
