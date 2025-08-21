{
  rustPlatform,
  fetchFromGitHub,
  nushell,
  emscripten,
  stdenvNoCC,
  writeText,
  typsitterGrammars,
}:
let
  grammarPathsJson = writeText "grammar-paths.json" (
    builtins.toJSON (builtins.attrValues typsitterGrammars)
  );
  treeSitterSource = fetchFromGitHub {
    owner = "tree-sitter";
    repo = "tree-sitter";
    rev = "0bb43f7afb5f0d83579007037a13d1fede636dbd";
    hash = "sha256-mEgH+vx4Emrkl9P7Str0511kM7e6axcL1ovF/cjUFmk=";
  };
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
in
stdenvNoCC.mkDerivation {
  name = "typsitter";
  src = ./.;
  nativeBuildInputs = [
    nushell
    emscripten
    wasi-stub
  ];
  buildPhase = ''
    nu -c '
      use typsitter.nu
      mkdir cache
      (EM_CACHE=$"($env.PWD)/cache" typsitter
        ...(open ${grammarPathsJson})
        --tree-sitter ${treeSitterSource}
        --output $env.out
      )
    '
  '';
}
