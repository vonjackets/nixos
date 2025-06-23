{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-25.05 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs, ... }:
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";

    pkgs = import nixpkgs { inherit system };

    #TODO: get paths
    modules = [
      # Import the previous configuration.nix we used,
      # so the old configuration file still takes effect
      ./builder.nix
    ];


  in
  {
    inherit system modules;
    # Please replace my-nixos with your hostname
    nixosConfigurations.nix-build = nixpkgs.lib.nixosSystem {
      system = system;
      modules = modules;
    };
  }
}
