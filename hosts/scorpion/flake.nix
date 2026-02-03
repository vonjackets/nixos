
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
