{
  description = "Functions for building Dart packages with Nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pub2nix = {
      url = "github:paulyoung/pub2nix";
      flake = false;
    };
  };

  outputs = { self, flake-utils, nixpkgs, pub2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        builders.buildDartPackage =
          let
            yamlLib = import "${pub2nix}/yaml.nix" { inherit pkgs; };
          in
            pkgs.callPackage ./build.nix { inherit yamlLib; };

        packages.pub2nix-lock = import "${pub2nix}/lock.nix" { inherit pkgs; };
      }
    );
}
