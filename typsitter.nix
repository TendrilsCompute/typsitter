{
  rustPlatform,
  fetchFromGitHub,
  nushell,
  emscripten,
  stdenvNoCC,
  typsitterGrammars,
  lib,
}:
let
  wasi-stub = rustPlatform.buildRustPackage rec {
    pname = "wasi-stub";
    version = "0.2.0";
    src = fetchFromGitHub {
      owner = "astrale-sharp";
      repo = "wasm-minimal-protocol";
      rev = "bb9ccd6b3f4bc554ffec61b89d7d8f15af6236b9";
      hash = "sha256-MgE2EqlkQ1c0iw+bqP3HlRJ92jRK5Sy9sJLrvKtQ/l0=";
    };
    cargoLock.lockFile = "${src}/Cargo.lock";
    cargoBuildFlags = "--bin wasi-stub";
    doCheck = false;
  };
  emccCache = stdenvNoCC.mkDerivation {
    name = "typsitter-emcc-cache";
    dontUnpack = true;
    nativeBuildInputs = [
      emscripten
    ];
    buildPhase = ''
      mkdir cache
      touch empty.c
      EM_CACHE="$PWD/cache" emcc empty.c --no-entry -O3 -o _.wasm
      tar -czf $out cache
    '';
  };
  treeSitterSource = fetchFromGitHub {
    owner = "tree-sitter";
    repo = "tree-sitter";
    rev = "0bb43f7afb5f0d83579007037a13d1fede636dbd";
    hash = "sha256-mEgH+vx4Emrkl9P7Str0511kM7e6axcL1ovF/cjUFmk=";
  };
  results = builtins.mapAttrs (
    name: path:
    stdenvNoCC.mkDerivation {
      name = "typsitter-${name}";
      src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
          ./typsitter.nu
          ./typsitter.c
        ];
      };
      nativeBuildInputs = [
        nushell
        emscripten
        wasi-stub
      ];
      buildPhase = ''
        tar -xzf ${emccCache}
        EM_CACHE=$"$PWD/cache" nu typsitter.nu \
          ${path} --tree-sitter ${treeSitterSource} --output $out
      '';
    }
  ) typsitterGrammars;
in
stdenvNoCC.mkDerivation {
  name = "typsitter";
  dontUnpack = true;
  buildPhase = ''
    mkdir -p $out/langs
    for result in ${builtins.concatStringsSep " " (builtins.attrValues results)}; do
      for lang in $result/langs/*; do
        cp $lang $out/langs
      done
      cat $result/langs.typ >> $out/langs.typ
    done
  '';
}
