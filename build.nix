{ lib
, yamlLib
, stdenv
, dart
, fetchzip
, runCommand
}:

{ pname
, version
, specFile
, lockFile
, dartFlags ? [ ]
, buildDir ? "build"
, buildType ? "release"
, src ? null
, srcs ? null
, ...
}@args:

assert builtins.pathExists specFile;
assert builtins.pathExists lockFile;
let
  specFile' = yamlLib.readYAML specFile;
  lockFile' = yamlLib.readYAML lockFile;

  pubCache =
    let
      step = (state: package:
        let
          pubCachePathParent = lib.concatStringsSep "/" [
            "$out"
            package.source
            (lib.removePrefix "https://" package.description.url)
          ];
          pubCachePath = lib.concatStringsSep "/" [
            pubCachePathParent
            "${package.description.name}-${package.version}"
          ];
          nixStorePath = fetchzip {
            inherit (package) sha256;
            stripRoot = false;
            url = lib.concatStringsSep "/" [
              package.description.url
              "packages"
              package.description.name
              "versions"
              "${package.version}.tar.gz"
            ];
          };
        in
        state + ''
          mkdir -p ${pubCachePathParent}
          ln -s ${nixStorePath} ${pubCachePath}
        ''
      );

      synthesize =
        builtins.foldl' step "" (builtins.attrValues lockFile'.packages);
    in
    runCommand "${pname}-pub-cache" { } synthesize;

  dartOpts = with lib;
    concatStringsSep " " ((optional (buildType == "debug") "--enable-asserts")
      ++ [ "-Dversion=${version}" ] ++ dartFlags);

  executables = specFile'.executables or { };
  
  buildBinaries =
    let
      inherit (lib) concatStringsSep mapAttrsToList;
      buildBin = name: path:
        with lib; ''
          dart ${dartOpts} compile exe -o "${buildDir}/${name}" "bin/${path}.dart"
        '';
      steps = mapAttrsToList buildBin executables;
    in
    concatStringsSep "\n" steps;
  
  installBinaries =
    let
      inherit (builtins) attrNames;
      inherit (lib) concatStringsSep mapAttrsToList;
      installBin = name: ''
        cp "${buildDir}/${name}" "$out/bin/${name}"
      '';
      steps = map installBin (attrNames executables);
    in
    concatStringsSep "\n" steps;

in
stdenv.mkDerivation ({
  PUB_CACHE = "${pubCache}";

  # Dart binaries are broken if stripped
  dontStrip = true;

  nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [ dart ];

  buildInputs = (args.buildInputs or [ ]);

  buildPhase = args.buildPhase or ''
    runHook preBuild

    mkdir -p "${buildDir}"

    # Some tooling still expects this file to exist
    touch .packages

    (
    set -x
    dart pub get --no-precompile --offline
    ${buildBinaries}
    )

    runHook postBuild
  '';

  installPhase = args.installPhase or ''
    runHook preInstall

    mkdir -p $out/bin
    ${installBinaries}

    runHook postInstall
  '';

  passthru = (args.passthru or { }) // { inherit pubCache; };

  meta = { platforms = dart.meta.platforms; } // (args.meta or { });
}
//
(removeAttrs args [
  "buildInputs"
  "buildPhase"
  "installPhase"
  "passthru"
  "meta"
]))
