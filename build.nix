{ lib
, yamlLib
, stdenv
, dart
, fetchzip
, makeWrapper
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

  dartOpts = with stdenv.lib;
    concatStringsSep " " ((optional (buildType == "debug") "--enable-asserts")
      ++ [ "-Dversion=${version}" ] ++ dartFlags);

  executables = specFile'.executables or { };

  buildSnapshots =
    let
      inherit (stdenv.lib) concatStringsSep mapAttrsToList;
      buildSnapshot = name: path:
        with stdenv.lib; ''
          dart ${dartOpts} --snapshot="${buildDir}/${name}.snapshot" "bin/${path}.dart"
        '';
      steps = mapAttrsToList buildSnapshot executables;
    in
    concatStringsSep "\n" steps;

  installSnapshots =
    let
      inherit (builtins) attrNames;
      inherit (stdenv.lib) concatStringsSep mapAttrsToList;
      installSnapshot = name: ''
        cp "${buildDir}/${name}.snapshot" "$out/lib/dart/${pname}/"
        makeWrapper "${dart}/bin/dart" "$out/bin/${name}" \
          --argv0 "${name}" \
          --add-flags "$out/lib/dart/${pname}/${name}.snapshot"
      '';
      steps = map installSnapshot (attrNames executables);
    in
    concatStringsSep "\n" steps;

in
stdenv.mkDerivation ({
  PUB_CACHE = "${pubCache}";

  nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [ makeWrapper ];

  buildInputs = (args.buildInputs or [ ]) ++ [ dart ];

  buildPhase = args.buildPhase or ''
    runHook preBuild

    mkdir -p "${buildDir}"

    # Some tooling still expects this file to exist
    touch .packages

    (
    set -x
    pub get --no-precompile --offline
    ${buildSnapshots}
    )

    runHook postBuild
  '';

  installPhase = args.installPhase or ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/dart/${pname}
    ${installSnapshots}

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
