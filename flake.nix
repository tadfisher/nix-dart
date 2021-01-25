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
    let
      builder = pkgs:
        let
          yamlLib = import "${pub2nix}/yaml.nix" { inherit pkgs; };
        in
        pkgs.callPackage ./build.nix { inherit yamlLib; };
    in
    {
      overlay = final: prev: {
        buildDartPackage = builder final;
        dart = final.callPackage ./pkgs/dart { channel = "stable"; };
        dart-beta = final.callPackage ./pkgs/dart { channel = "beta"; };
        dart-dev = final.callPackage ./pkgs/dart { channel = "dev"; };
        pub2nix-lock = import "${pub2nix}/lock.nix" { pkgs = final; };
      };
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        builders.buildDartPackage = builder pkgs;

        packages = rec {
          dart = pkgs.callPackage ./pkgs/dart { channel = "stable"; };
          dart-beta = pkgs.callPackage ./pkgs/dart { channel = "beta"; };
          dart-dev = pkgs.callPackage ./pkgs/dart { channel = "dev"; };
          pub2nix-lock = import "${pub2nix}/lock.nix" { inherit pkgs; };
        };
      }
    );
}
