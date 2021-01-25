# nix-dart

Build Dart packages with Nix.

## Usage

This project requires [Nix Flakes](https://nixos.wiki/wiki/Flakes), which is currently an unstable
feature.

Given a Dart project tree with a `pubspec.yaml` and `pubspec.lock`, run the following to generate
a `pub2nix.lock` file.

```
nix run github:tadfisher/nix-dart#pub2nix-lock
```

In the derivation building the project, use `builders.${system}.buildDartPackage` from this flake.
The required arguments are

- `specFile`: Path to `pubspec.yaml` for the project. Usually packaged with the source tree.
- `lockFile`: Path to the generated `pub2nix.lock`. It's easiest to distribute this alongside the
  Nix derivation.

An example derivation for `dart-sass` follows.

```nix
{ lib, stdenv, fetchFromGitHub, buildDartPackage }:

buildDartPackage rec {
  pname = "dart-sass";
  version = "1.32.5";

  src = fetchFromGitHub {
    owner = "sass";
    repo = pname;
    rev = version;
    hash = "sha256-HNviEUUgLdDH8WN8rXwtZ8t4u8s/nIs7iITCiBF7pas=";
  };

  specFile = "${src}/pubspec.yaml";
  lockFile = ./pub2nix.lock;

  meta = with lib; {
    description = "The reference implementation of Sass, written in Dart";
    homepage = "https://sass-lang.com/dart-sass";
    maintainers = [ maintainers.tadfisher ];
    license = licenses.mit;
  };
}
```

Up-to-date Dart SDK packages are available in `packages.${system}`: `dart`, `dart-beta`, and
`dart-dev`. These are checked daily and updated via CI.

`buildDartPackage`, `pub2nix-lock`, and the Dart SDK packages are also available in `overlay`.

A binary cache is available at [nix-dart.cachix.org](https://nix-dart.cachix.org).

## Thanks

Thanks to [Paul Young](https://github.com/paulyoung) for creating
[pub2nix](https://github.com/paulyoung/pub2nix). This project passes through `pub2nix-lock`, and
`buildDartPackage` is based on my previous efforts to package Dart projects merged with `pub2nix`'s
mechanism to generate the offline dependency cache.

## License

[Apache 2.0](./LICENSE).
